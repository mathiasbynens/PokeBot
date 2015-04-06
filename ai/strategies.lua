local strategies = {}

local combat = require "ai.combat"
local control = require "ai.control"

local battle = require "action.battle"
local textbox = require "action.textbox"
local walk = require "action.walk"

local bridge = require "util.bridge"
local input = require "util.input"
local memory = require "util.memory"
local menu = require "util.menu"
local player = require "util.player"
local utils = require "util.utils"

local inventory = require "storage.inventory"
local pokemon = require "storage.pokemon"

local splitNumber, splitTime = 0, 0
local resetting
local strategyFunctions

local status = {tries = 0, tempDir = nil, canProgress = nil, initialized = false}
strategies.status = status
strategies.deepRun = false

-- RISK/RESET

strategies.timeRequirements = {}

function strategies.getTimeRequirement(name)
	return strategies.timeRequirements[name]()
end

function strategies.hardReset(message, extra, wait)
	resetting = true
	if strategies.seed then
		if extra then
			extra = extra.." | "..strategies.seed
		else
			extra = strategies.seed
		end
	end
	bridge.chat(message, extra)
	if wait and INTERNAL and not STREAMING_MODE then
		strategyFunctions.wait()
	end
	client.reboot_core()
	return true
end

function strategies.reset(reason, extra, wait)
	local time = utils.elapsedTime()
	local resetString = "Reset"
	if time then
		resetString = resetString.." after "..time
	end
	resetString = " "..resetString.." at "..control.areaName
	local separator
	if strategies.deepRun and not control.yolo then
		separator = " BibleThump"
	else
		separator = ":"
	end
	resetString = resetString..separator.." "..reason
	return strategies.hardReset(resetString, extra, wait)
end

function strategies.death(extra)
	local reason
	if strategies.criticaled then
		reason = "Critical'd"
	elseif control.yolo then
		reason = "Yolo strats"
	else
		reason = "Died"
	end
	return strategies.reset(reason, extra)
end

function strategies.overMinute(min)
	return utils.igt() > min * 60
end

function strategies.resetTime(timeLimit, reason, once)
	if strategies.overMinute(timeLimit) then
		reason = "Took too long to "..reason
		if RESET_FOR_TIME then
			return strategies.reset(reason)
		end
		if once then
			print(reason.." "..utils.elapsedTime())
		end
	end
end

function strategies.setYolo(name)
	if not RESET_FOR_TIME then
		return false
	end
	local minimumTime = strategies.getTimeRequirement(name)
	local shouldYolo = strategies.overMinute(minimumTime)
	if control.yolo ~= shouldYolo then
		control.yolo = shouldYolo
		control.setYolo(shouldYolo)
		local prefix
		if control.yolo then
			prefix = "en"
		else
			prefix = "dis"
		end
		print("YOLO "..prefix.."abled at "..control.areaName)
	end
	return control.yolo
end

-- HELPERS

function strategies.initialize()
	if not initialized then
		initialized = true
		return true
	end
end

function strategies.canHealFor(damage)
	local curr_hp = pokemon.index(0, "hp")
	local max_hp = pokemon.index(0, "max_hp")
	if max_hp - curr_hp > 3 then
		local healChecks = {"full_restore", "super_potion", "potion"}
		for idx,potion in ipairs(healChecks) do
			if inventory.contains(potion) and utils.canPotionWith(potion, damage, curr_hp, max_hp) then
				return potion
			end
		end
	end
end

function strategies.hasHealthFor(opponent, extra)
	if not extra then
		extra = 0
	end
	return pokemon.index(0, "hp") + extra > combat.healthFor(opponent)
end

function strategies.damaged(factor)
	if not factor then
		factor = 1
	end
	return pokemon.index(0, "hp") * factor < pokemon.index(0, "max_hp")
end

function strategies.opponentDamaged(factor)
	if not factor then
		factor = 1
	end
	return memory.double("battle", "opponent_hp") * factor < memory.double("battle", "opponent_max_hp")
end

function strategies.redHP()
	return math.ceil(pokemon.index(0, "max_hp") * 0.2)
end

function strategies.buffTo(buff, defLevel)
	if battle.isActive() then
		canProgress = true
		local forced
		if defLevel and memory.double("battle", "opponent_defense") > defLevel then
			forced = buff
		end
		battle.automate(forced, true)
	elseif canProgress then
		return true
	else
		battle.automate()
	end
end

function strategies.dodgeUp(npc, sx, sy, dodge, offset)
	if not battle.handleWild() then
		return false
	end
	local px, py = player.position()
	if py < sy - 1 then
		return true
	end
	local wx, wy = px, py
	if py < sy then
		wy = py - 1
	elseif px == sx or px == dodge then
		if px - memory.raw(npc) == offset then
			if px == sx then
				wx = dodge
			else
				wx = sx
			end
		else
			wy = py - 1
		end
	end
	walk.step(wx, wy)
end

local function dodgeH(options)
	local left = 1
	if options.left then
		left = -1
	end
	local px, py = player.position()
	if px * left > options.sx * left + (options.dist or 1) * left then
		return true
	end
	local wx, wy = px, py
	if px * left > options.sx * left then
		wx = px + 1 * left
	elseif py == options.sy or py == options.dodge then
		if py - memory.raw(options.npc) == options.offset then
			if py == options.sy then
				wy = options.dodge
			else
				wy = options.sy
			end
		else
			wx = px + 1 * left
		end
	end
	walk.step(wx, wy)
end

function strategies.completedMenuFor(data)
	local count = inventory.count(data.item)
	if count == 0 or count + (data.amount or 1) <= status.tries then
		return true
	end
	return false
end

function strategies.closeMenuFor(data)
	if (not tempDir and not data.close) or data.chain or menu.close() then
		return true
	end
end

function strategies.useItem(data)
	local main = memory.value("menu", "main")
	if status.tries == 0 then
		status.tries = inventory.count(data.item)
		if status.tries == 0 then
			if strategies.closeMenuFor(data) then
				return true
			end
			return false
		end
	end
	if strategies.completedMenuFor(data) then
		if strategies.closeMenuFor(data) then
			return true
		end
	else
		if inventory.use(data.item, data.poke) then
			tempDir = true
		else
			menu.pause()
		end
	end
end

local function completedSkillFor(data)
	if data.map then
		if data.map ~= memory.value("game", "map") then
			return true
		end
	elseif data.x or data.y then
		local px, py = player.position()
		if data.x == px or data.y == py then
			return true
		end
	elseif data.done then
		if memory.raw(data.done) > (data.val or 0) then
			return true
		end
	elseif status.tries > 0 and not menu.isOpen() then
		return true
	end
	return false
end

function strategies.isPrepared(...)
	if status.tries == 0 then
		status.tries = {}
	end
	for i,name in ipairs(arg) do
		local currentCount = inventory.count(name)
		if currentCount > 0 then
			local previousCount = status.tries[name]
			if previousCount == nil or currentCount == previousCount then
				return false
			end
		end
	end
	return true
end

function strategies.prepare(...)
	if status.tries == 0 then
		status.tries = {}
	end
	local item
	for idx,name in ipairs(arg) do
		local currentCount = inventory.count(name)
		local needsItem = currentCount > 0
		local previousCount = status.tries[name]
		if previousCount == nil then
			status.tries[name] = currentCount
		elseif needsItem then
			needsItem = currentCount == previousCount
		end
		if needsItem then
			item = name
			break
		end
	end
	if not item then
		return true
	end
	if battle.isActive() then
		inventory.use(item, nil, true)
	else
		input.cancel()
	end
end

-- GENERALIZED STRATEGIES

strategies.functions = {

	startFrames = function()
		strategies.frames = 0
		return true
	end,

	reportFrames = function()
		print("FR "..strategies.frames)
		local repels = memory.value("player", "repel")
		if repels > 0 then
			print("S "..repels)
		end
		strategies.frames = nil
		return true
	end,

	split = function(data)
		bridge.split(data and data.finished)
		if not INTERNAL then
			splitNumber = splitNumber + 1

			local timeDiff
			splitTime, timeDiff = utils.timeSince(splitTime)
			if timeDiff then
				print(splitNumber..". "..control.areaName..": "..utils.elapsedTime().." ("..timeDiff..")")
			end
		end
		return true
	end,

	interact = function(data)
		if battle.handleWild() then
			if battle.isActive() then
				return true
			end
			if textbox.isActive() then
				if status.tries > 0 then
					return true
				end
				status.tries = status.tries - 1
				input.cancel()
			elseif player.interact(data.dir) then
				status.tries = status.tries + 1
			end
		end
	end,

	confirm = function(data)
		if battle.handleWild() then
			if textbox.isActive() then
				status.tries = status.tries + 1
				input.cancel(data.type or "A")
			else
				if status.tries > 0 then
					return true
				end
				player.interact(data.dir)
			end
		end
	end,

	item = function(data)
		if battle.handleWild() then
			if data.full and not inventory.isFull() then
				if strategies.closeMenuFor(data) then
					return true
				end
				return false
			end
			return strategies.useItem(data)
		end
	end,

	potion = function(data)
		local curr_hp = pokemon.index(0, "hp")
		if curr_hp == 0 then
			return false
		end
		local toHP
		if control.yolo and data.yolo ~= nil then
			toHP = data.yolo
		else
			toHP = data.hp
		end
		if type(toHP) == "string" then
			toHP = combat.healthFor(toHP)
		end
		local toHeal = toHP - curr_hp
		if toHeal > 0 then
			local toPotion
			if data.forced then
				toPotion = inventory.contains(data.forced)
			else
				local p_first, p_second, p_third
				if toHeal > 50 then
					if data.full then
						p_first = "full_restore"
					else
						p_first = "super_potion"
					end
					p_second, p_third = "super_potion", "potion"
				else
					if toHeal > 20 then
						p_first, p_second = "super_potion", "potion"
					else
						p_first, p_second = "potion", "super_potion"
					end
					if data.full then
						p_third = "full_restore"
					end
				end
				toPotion = inventory.contains(p_first, p_second, p_third)
			end
			if toPotion then
				if menu.pause() then
					inventory.use(toPotion)
					tempDir = true
				end
				return false
			end
			--TODO report wanted potion
		end
		if strategies.closeMenuFor(data) then
			return true
		end
	end,

	teach = function(data)
		if data.full and not inventory.isFull() then
			return true
		end
		local itemName
		if data.item then
			itemName = data.item
		else
			itemName = data.move
		end
		if pokemon.hasMove(data.move) then
			local main = memory.value("menu", "main")
			if main == 128 then
				if data.chain then
					return true
				end
			elseif main < 3 then
				return true
			end
			input.press("B")
		else
			if strategies.initialize() then
				if not inventory.contains(itemName) then
					return strategies.reset("Unable to teach move "..itemName.." to "..data.poke, nil, true)
				end
			end
			local replacement
			if data.replace then
				replacement = pokemon.moveIndex(data.replace, data.poke) - 1
			else
				replacement = 0
			end
			if inventory.teach(itemName, data.poke, replacement, data.alt) then
				tempDir = true
			else
				menu.pause()
			end
		end
	end,

	skill = function(data)
		if completedSkillFor(data) then
			if not textbox.isActive() then
				return true
			end
			input.press("B")
		elseif not data.dir or player.face(data.dir) then
			if pokemon.use(data.move) then
				status.tries = status.tries + 1
			else
				menu.pause()
			end
		end
	end,

	fly = function(data)
		if memory.value("game", "map") == data.map then
			return true
		end
		local cities = {
			pallet = {62, "Up"},
			viridian = {63, "Up"},
			lavender = {66, "Down"},
			celadon = {68, "Down"},
			fuchsia = {69, "Down"},
			cinnabar = {70, "Down"},
		}

		local main = memory.value("menu", "main")
		if main == 228 then
			local currentFly = memory.raw(0x1FEF)
			local destination = cities[data.dest]
			local press
			if destination[1] - currentFly == 0 then
				press = "A"
			else
				press = destination[2]
			end
			input.press(press)
		elseif not pokemon.use("fly") then
			menu.pause()
		end
	end,

	bicycle = function()
		if memory.raw(0x1700) == 1 then
			if textbox.handle() then
				return true
			end
		else
			return strategies.useItem({item="bicycle"})
		end
	end,

	wait = function()
		print("Please save state")
		input.press("Start", 9001)
	end,

	emuSpeed = function(data)
		-- client.speedmode = data.percent
		return true
	end,

	waitToTalk = function()
		if battle.isActive() then
			canProgress = false
			battle.automate()
		elseif textbox.isActive() then
			canProgress = true
			input.cancel()
		elseif canProgress then
			return true
		end
	end,

	waitToPause = function()
		local main = memory.value("menu", "main")
		if main == 128 then
			if canProgress then
				return true
			end
		elseif battle.isActive() then
			canProgress = false
			battle.automate()
		elseif main == 123 then
			canProgress = true
			input.press("B")
		elseif textbox.handle() then
			input.press("Start", 2)
		end
	end,

	waitToFight = function(data)
		if battle.isActive() then
			canProgress = true
			battle.automate()
		elseif canProgress then
			return true
		elseif textbox.handle() then
			if data.dir then
				player.interact(data.dir)
			else
				input.cancel()
			end
		end
	end,

	allowDeath = function(data)
		control.canDie(data.on)
		return true
	end,

	-- ROUTE

	dodgePalletBoy = function()
		return strategies.dodgeUp(0x0223, 14, 14, 15, 7)
	end,

	helix = function()
		if battle.handleWild() then
			if inventory.contains("helix_fossil") then
				return true
			end
			player.interact("Up")
		end
	end,

	dodgeCerulean = function()
		return dodgeH{
			npc = 0x0242,
			sx = 14, sy = 18,
			dodge = 19,
			offset = 10,
			dist = 4
		}
	end,

	dodgeCeruleanLeft = function()
		return dodgeH{
			npc = 0x0242,
			sx = 16, sy = 18,
			dodge = 17,
			offset = 10,
			dist = -7,
			left = true
		}
	end,

	playPokeflute = function()
		if battle.isActive() then
			return true
		end
		if memory.value("battle", "menu") == 95 then
			input.press("A")
		elseif menu.pause() then
			inventory.use("pokeflute")
		end
	end,

	push = function(data)
		local pos
		if data.dir == "Up" or data.dir == "Down" then
			pos = data.y
		else
			pos = data.x
		end
		local newP = memory.raw(pos)
		if status.tries == 0 then
			status.tries = {start=newP}
		elseif status.tries.start ~= newP then
			return true
		end
		input.press(data.dir, 0)
	end,
}

strategyFunctions = strategies.functions

function strategies.execute(data)
	if strategyFunctions[data.s](data) then
		status = {tries=0}
		if resetting then
			return nil
		end
		-- print(data.s)
		return true
	end
	return false
end

function strategies.init(midGame)
	if not STREAMING_MODE then
		splitTime = utils.timeSince(0)
	end
	if midGame then
		combat.factorPP(true)
	end
	strategies.initGame(midGame)
end

function strategies.softReset()
	status = {}
	splitNumber, splitTime = 0, 0
	resetting = nil
	strategies.resetGame()
end

return strategies
