local Strategies = {}

local Combat = require "ai.combat"
local Control = require "ai.control"

local Battle = require "action.battle"
local Textbox = require "action.textbox"
local Walk = require "action.walk"

local Bridge = require "util.bridge"
local Input = require "util.input"
local Memory = require "util.memory"
local Menu = require "util.menu"
local Player = require "util.player"
local Utils = require "util.utils"

local Inventory = require "storage.inventory"
local Pokemon = require "storage.pokemon"

local splitNumber, splitTime = 0, 0
local resetting
local strategyFunctions

local status = {tries = 0, tempDir = nil, canProgress = nil, initialized = false}
Strategies.status = status
Strategies.deepRun = false

-- RISK/RESET

Strategies.timeRequirements = {}

function Strategies.getTimeRequirement(name)
	return Strategies.timeRequirements[name]()
end

function Strategies.hardReset(message, extra, wait)
	resetting = true
	if Strategies.seed then
		if extra then
			extra = extra.." | "..Strategies.seed
		else
			extra = Strategies.seed
		end
	end
	Bridge.chat(message, extra)
	if wait and INTERNAL and not STREAMING_MODE then
		strategyFunctions.wait()
	end
	client.reboot_core()
	return true
end

function Strategies.reset(reason, extra, wait)
	local time = Utils.elapsedTime()
	local resetString = "Reset"
	if time then
		resetString = resetString.." after "..time
	end
	resetString = " "..resetString.." at "..Control.areaName
	local separator
	if Strategies.deepRun and not Control.yolo then
		separator = " BibleThump"
	else
		separator = ":"
	end
	resetString = resetString..separator.." "..reason
	return Strategies.hardReset(resetString, extra, wait)
end

function Strategies.death(extra)
	local reason
	if Strategies.criticaled then
		reason = "Critical'd"
	elseif Control.yolo then
		reason = "Yolo strats"
	else
		reason = "Died"
	end
	return Strategies.reset(reason, extra)
end

function Strategies.overMinute(min)
	return Utils.igt() > min * 60
end

function Strategies.resetTime(timeLimit, reason, once)
	if Strategies.overMinute(timeLimit) then
		reason = "Took too long to "..reason
		if RESET_FOR_TIME then
			return Strategies.reset(reason)
		end
		if once then
			print(reason.." "..Utils.elapsedTime())
		end
	end
end

function Strategies.setYolo(name)
	if not RESET_FOR_TIME then
		return false
	end
	local minimumTime = Strategies.getTimeRequirement(name)
	local shouldYolo = Strategies.overMinute(minimumTime)
	if Control.yolo ~= shouldYolo then
		Control.yolo = shouldYolo
		Control.setYolo(shouldYolo)
		local prefix
		if Control.yolo then
			prefix = "en"
		else
			prefix = "dis"
		end
		print("YOLO "..prefix.."abled at "..Control.areaName)
	end
	return Control.yolo
end

-- HELPERS

function Strategies.initialize()
	if not status.initialized then
		status.initialized = true
		return true
	end
end

function Strategies.canHealFor(damage)
	local curr_hp = Pokemon.index(0, "hp")
	local max_hp = Pokemon.index(0, "max_hp")
	if max_hp - curr_hp > 3 then
		local healChecks = {"full_restore", "super_potion", "potion"}
		for idx,potion in ipairs(healChecks) do
			if Inventory.contains(potion) and Utils.canPotionWith(potion, damage, curr_hp, max_hp) then
				return potion
			end
		end
	end
end

function Strategies.hasHealthFor(opponent, extra)
	if not extra then
		extra = 0
	end
	return Pokemon.index(0, "hp") + extra > Combat.healthFor(opponent)
end

function Strategies.damaged(factor)
	if not factor then
		factor = 1
	end
	return Pokemon.index(0, "hp") * factor < Pokemon.index(0, "max_hp")
end

function Strategies.opponentDamaged(factor)
	if not factor then
		factor = 1
	end
	return Memory.double("battle", "opponent_hp") * factor < Memory.double("battle", "opponent_max_hp")
end

function Strategies.redHP()
	return math.ceil(Pokemon.index(0, "max_hp") * 0.2)
end

function Strategies.buffTo(buff, defLevel)
	if Battle.isActive() then
		status.canProgress = true
		local forced
		if defLevel and Memory.double("battle", "opponent_defense") > defLevel then
			forced = buff
		end
		Battle.automate(forced, true)
	elseif status.canProgress then
		return true
	else
		Battle.automate()
	end
end

function Strategies.dodgeUp(npc, sx, sy, dodge, offset)
	if not Battle.handleWild() then
		return false
	end
	local px, py = Player.position()
	if py < sy - 1 then
		return true
	end
	local wx, wy = px, py
	if py < sy then
		wy = py - 1
	elseif px == sx or px == dodge then
		if px - Memory.raw(npc) == offset then
			if px == sx then
				wx = dodge
			else
				wx = sx
			end
		else
			wy = py - 1
		end
	end
	Walk.step(wx, wy)
end

local function dodgeH(options)
	local left = 1
	if options.left then
		left = -1
	end
	local px, py = Player.position()
	if px * left > options.sx * left + (options.dist or 1) * left then
		return true
	end
	local wx, wy = px, py
	if px * left > options.sx * left then
		wx = px + 1 * left
	elseif py == options.sy or py == options.dodge then
		if py - Memory.raw(options.npc) == options.offset then
			if py == options.sy then
				wy = options.dodge
			else
				wy = options.sy
			end
		else
			wx = px + 1 * left
		end
	end
	Walk.step(wx, wy)
end

function Strategies.completedMenuFor(data)
	local count = Inventory.count(data.item)
	if count == 0 or count + (data.amount or 1) <= status.tries then
		return true
	end
	return false
end

function Strategies.closeMenuFor(data)
	if (not status.tempDir and not data.close) or data.chain or Menu.close() then
		return true
	end
end

function Strategies.useItem(data)
	local main = Memory.value("menu", "main")
	if status.tries == 0 then
		status.tries = Inventory.count(data.item)
		if status.tries == 0 then
			if Strategies.closeMenuFor(data) then
				return true
			end
			return false
		end
	end
	if Strategies.completedMenuFor(data) then
		if Strategies.closeMenuFor(data) then
			return true
		end
	else
		if Inventory.use(data.item, data.poke) then
			status.tempDir = true
		else
			Menu.pause()
		end
	end
end

local function completedSkillFor(data)
	if data.map then
		if data.map ~= Memory.value("game", "map") then
			return true
		end
	elseif data.x or data.y then
		local px, py = Player.position()
		if data.x == px or data.y == py then
			return true
		end
	elseif data.done then
		if Memory.raw(data.done) > (data.val or 0) then
			return true
		end
	elseif status.tries > 0 and not Menu.isOpen() then
		return true
	end
	return false
end

function Strategies.isPrepared(...)
	if status.tries == 0 then
		status.tries = {}
	end
	for i,name in ipairs(arg) do
		local currentCount = Inventory.count(name)
		if currentCount > 0 then
			local previousCount = status.tries[name]
			if previousCount == nil or currentCount == previousCount then
				return false
			end
		end
	end
	return true
end

function Strategies.prepare(...)
	if status.tries == 0 then
		status.tries = {}
	end
	local item
	for idx,name in ipairs(arg) do
		local currentCount = Inventory.count(name)
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
	if Battle.isActive() then
		Inventory.use(item, nil, true)
	else
		Input.cancel()
	end
end

-- GENERALIZED STRATEGIES

Strategies.functions = {

	startFrames = function()
		Strategies.frames = 0
		return true
	end,

	reportFrames = function()
		print("FR "..Strategies.frames)
		local repels = Memory.value("player", "repel")
		if repels > 0 then
			print("S "..repels)
		end
		Strategies.frames = nil
		return true
	end,

	split = function(data)
		Bridge.split(data and data.finished)
		if not INTERNAL then
			splitNumber = splitNumber + 1

			local timeDiff
			splitTime, timeDiff = Utils.timeSince(splitTime)
			if timeDiff then
				print(splitNumber..". "..Control.areaName..": "..Utils.elapsedTime().." ("..timeDiff..")")
			end
		end
		return true
	end,

	interact = function(data)
		if Battle.handleWild() then
			if Battle.isActive() then
				return true
			end
			if Textbox.isActive() then
				if status.tries > 0 then
					return true
				end
				status.tries = status.tries - 1
				Input.cancel()
			elseif Player.interact(data.dir) then
				status.tries = status.tries + 1
			end
		end
	end,

	confirm = function(data)
		if Battle.handleWild() then
			if Textbox.isActive() then
				status.tries = status.tries + 1
				Input.cancel(data.type or "A")
			else
				if status.tries > 0 then
					return true
				end
				Player.interact(data.dir)
			end
		end
	end,

	item = function(data)
		if Battle.handleWild() then
			if data.full and not Inventory.isFull() then
				if Strategies.closeMenuFor(data) then
					return true
				end
				return false
			end
			return Strategies.useItem(data)
		end
	end,

	potion = function(data)
		local curr_hp = Pokemon.index(0, "hp")
		if curr_hp == 0 then
			return false
		end
		local toHP
		if Control.yolo and data.yolo ~= nil then
			toHP = data.yolo
		else
			toHP = data.hp
		end
		if type(toHP) == "string" then
			toHP = Combat.healthFor(toHP)
		end
		local toHeal = toHP - curr_hp
		if toHeal > 0 then
			local toPotion
			if data.forced then
				toPotion = Inventory.contains(data.forced)
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
				toPotion = Inventory.contains(p_first, p_second, p_third)
			end
			if toPotion then
				if Menu.pause() then
					Inventory.use(toPotion)
					status.tempDir = true
				end
				return false
			end
			--TODO report wanted potion
		end
		if Strategies.closeMenuFor(data) then
			return true
		end
	end,

	teach = function(data)
		if data.full and not Inventory.isFull() then
			return true
		end
		local itemName
		if data.item then
			itemName = data.item
		else
			itemName = data.move
		end
		if Pokemon.hasMove(data.move) then
			local main = Memory.value("menu", "main")
			if main == 128 then
				if data.chain then
					return true
				end
			elseif main < 3 then
				return true
			end
			Input.press("B")
		else
			if Strategies.initialize() then
				if not Inventory.contains(itemName) then
					return Strategies.reset("Unable to teach move "..itemName.." to "..data.poke, nil, true)
				end
			end
			local replacement
			if data.replace then
				replacement = Pokemon.moveIndex(data.replace, data.poke) - 1
			else
				replacement = 0
			end
			if Inventory.teach(itemName, data.poke, replacement, data.alt) then
				status.tempDir = true
			else
				Menu.pause()
			end
		end
	end,

	skill = function(data)
		if completedSkillFor(data) then
			if not Textbox.isActive() then
				return true
			end
			Input.press("B")
		elseif not data.dir or Player.face(data.dir) then
			if Pokemon.use(data.move) then
				status.tries = status.tries + 1
			else
				Menu.pause()
			end
		end
	end,

	fly = function(data)
		if Memory.value("game", "map") == data.map then
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

		local main = Memory.value("menu", "main")
		if main == 228 then
			local currentFly = Memory.raw(0x1FEF)
			local destination = cities[data.dest]
			local press
			if destination[1] - currentFly == 0 then
				press = "A"
			else
				press = destination[2]
			end
			Input.press(press)
		elseif not Pokemon.use("fly") then
			Menu.pause()
		end
	end,

	bicycle = function()
		if Memory.raw(0x1700) == 1 then
			if Textbox.handle() then
				return true
			end
		else
			return Strategies.useItem({item="bicycle"})
		end
	end,

	wait = function()
		print("Please save state")
		Input.press("Start", 9001)
	end,

	emuSpeed = function(data)
		-- client.speedmode = data.percent
		return true
	end,

	waitToTalk = function()
		if Battle.isActive() then
			status.canProgress = false
			Battle.automate()
		elseif Textbox.isActive() then
			status.canProgress = true
			Input.cancel()
		elseif status.canProgress then
			return true
		end
	end,

	waitToPause = function()
		local main = Memory.value("menu", "main")
		if main == 128 then
			if status.canProgress then
				return true
			end
		elseif Battle.isActive() then
			status.canProgress = false
			Battle.automate()
		elseif main == 123 then
			status.canProgress = true
			Input.press("B")
		elseif Textbox.handle() then
			Input.press("Start", 2)
		end
	end,

	waitToFight = function(data)
		if Battle.isActive() then
			status.canProgress = true
			Battle.automate()
		elseif status.canProgress then
			return true
		elseif Textbox.handle() then
			if data.dir then
				Player.interact(data.dir)
			else
				Input.cancel()
			end
		end
	end,

	allowDeath = function(data)
		Control.canDie(data.on)
		return true
	end,

	-- ROUTE

	dodgePalletBoy = function()
		return Strategies.dodgeUp(0x0223, 14, 14, 15, 7)
	end,

	helix = function()
		if Battle.handleWild() then
			if Inventory.contains("helix_fossil") then
				return true
			end
			Player.interact("Up")
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
		if Battle.isActive() then
			return true
		end
		if Memory.value("battle", "menu") == 95 then
			Input.press("A")
		elseif Menu.pause() then
			Inventory.use("pokeflute")
		end
	end,

	push = function(data)
		local pos
		if data.dir == "Up" or data.dir == "Down" then
			pos = data.y
		else
			pos = data.x
		end
		local newP = Memory.raw(pos)
		if status.tries == 0 then
			status.tries = {start=newP}
		elseif status.tries.start ~= newP then
			return true
		end
		Input.press(data.dir, 0)
	end,
}

strategyFunctions = Strategies.functions

function Strategies.execute(data)
	if strategyFunctions[data.s](data) then
		status = {tries=0}
		Strategies.status = status
		Strategies.completeGameStrategy()
		-- print(data.s)
		if resetting then
			return nil
		end
		return true
	end
	return false
end

function Strategies.init(midGame)
	if not STREAMING_MODE then
		splitTime = Utils.timeSince(0)
	end
	if midGame then
		Combat.factorPP(true)
	end
	Strategies.initGame(midGame)
end

function Strategies.softReset()
	status = {tries=0}
	Strategies.status = status
	splitNumber, splitTime = 0, 0
	resetting = nil
	Strategies.resetGame()
end

return Strategies
