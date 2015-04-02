local strategies = {}

local combat = require "ai.combat"
local control = require "ai.control"

local battle = require "action.battle"
local shop = require "action.shop"
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

local areaName = "Unknown"
local splitNumber, splitTime = 0, 0
local tries = 0
local tempDir, canProgress, initialized
local level4Nidoran = true -- 57 vs 96 (d39)
local nidoAttack, nidoSpeed, nidoSpecial = 0, 0, 0
local squirtleAtt, squirtleDef, squirtleSpd, squirtleScl
local yolo, deepRun, resetting, riskGiovanni, maxEtherSkip

-- TIME CONSTRAINTS

local timeRequirements = {

	bulbasaur = function()
		return 2.25
	end,

	nidoran = function()
		local timeLimit = 6.25
		if pokemon.inParty("spearow") then
			timeLimit = timeLimit + 0.67
		end
		return timeLimit
	end,

	mt_moon = function()
		local timeLimit = 27
		if nidoAttack > 15 and nidoSpeed > 14 then
			timeLimit = timeLimit + 0.25
		end
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	mankey = function()
		local timeLimit = 33
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	goldeen = function()
		local timeLimit = 38
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	misty = function()
		local timeLimit = 40
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	vermilion = function()
		return 44.25
	end,

	trash = function()
		local timeLimit = 47
		if nidoSpecial > 44 then
			timeLimit = timeLimit + 0.25
		end
		if nidoAttack > 53 then
			timeLimit = timeLimit + 0.25
		end
		if nidoAttack >= 54 and nidoSpecial >= 45 then
			timeLimit = timeLimit + 0.25
		end
		return timeLimit
	end,

	safari_carbos = function()
		return 70.5
	end,

	e4center = function()
		return 102
	end,

	blue = function()
		return 108.2
	end,
}

-- RISK/RESET

local function hardReset(message, extra)
	resetting = true
	if strategies.seed then
		if extra then
			extra = extra.." | "..strategies.seed
		else
			extra = strategies.seed
		end
	end
	bridge.chat(message, extra)
	client.reboot_core()
	return true
end

local function reset(reason, extra)
	local time = utils.elapsedTime()
	local resetString = "Reset"
	if time then
		resetString = resetString.." after "..time
	end
	if areaName then
		resetString = " "..resetString.." at "..areaName
	end
	local separator
	if deepRun and not yolo then
		separator = " BibleThump"
	else
		separator = ":"
	end
	resetString = resetString..separator.." "..reason
	return hardReset(resetString, extra)
end
strategies.reset = reset

local function resetDeath(extra)
	local reason
	if strategies.criticaled then
		reason = "Critical'd"
	elseif yolo then
		reason = "Yolo strats"
	else
		reason = "Died"
	end
	return reset(reason, extra)
end
strategies.death = resetDeath

local function overMinute(min)
	return utils.igt() > min * 60
end

local function resetTime(timeLimit, reason, once)
	if overMinute(timeLimit) then
		reason = "Took too long to "..reason
		if RESET_FOR_TIME then
			return reset(reason)
		end
		if once then
			print(reason.." "..utils.elapsedTime())
		end
	end
end

local function getTimeRequirement(name)
	return timeRequirements[name]()
end

local function setYolo(name)
	local minimumTime = getTimeRequirement(name)
	local shouldYolo = overMinute(minimumTime)
	if yolo ~= shouldYolo then
		yolo = shouldYolo
		control.setYolo(shouldYolo)
		local prefix
		if yolo then
			prefix = "en"
		else
			prefix = "dis"
		end
		if areaName then
			print("YOLO "..prefix.."abled at "..areaName)
		else
			print("YOLO "..prefix.."abled")
		end
	end
	return yolo
end

-- PRIVATE

local function initialize()
	if not initialized then
		initialized = true
		return true
	end
end

local function canHealFor(damage)
	local healChecks = {
		{"full_restore", 9001},
		{"super_potion", 50},
		{"potion", 20},
	}
	local curr_hp = pokemon.index(0, "hp")
	local max_hp = pokemon.index(0, "max_hp")
	for idx,potion in ipairs(healChecks) do
		local name = potion[1]
		local result_hp = math.min(curr_hp + potion[2], max_hp)
		if result_hp >= damage and inventory.contains(name) then
			return name
		end
	end
end

local function hasHealthFor(opponent, extra)
	if not extra then
		extra = 0
	end
	return pokemon.index(0, "hp") + extra > combat.healthFor(opponent)
end

local function damaged(factor)
	if not factor then
		factor = 1
	end
	return pokemon.index(0, "hp") * factor < pokemon.index(0, "max_hp")
end

local function opponentDamaged(factor)
	if not factor then
		factor = 1
	end
	return memory.double("battle", "opponent_hp") * factor < memory.double("battle", "opponent_max_hp")
end

local function redHP()
	return math.ceil(pokemon.index(0, "max_hp") * 0.2)
end

local function buffTo(buff, defLevel)
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

local function dodgeUp(npc, sx, sy, dodge, offset)
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

local function completedMenuFor(data)
	local count = inventory.count(data.item)
	if count == 0 or count + (data.amount or 1) <= tries then
		return true
	end
	return false
end

local function closeMenuFor(data)
	if (not tempDir and not data.close) or data.chain or menu.close() then
		return true
	end
end

local function useItem(data)
	local main = memory.value("menu", "main")
	if tries == 0 then
		tries = inventory.count(data.item)
		if tries == 0 then
			if closeMenuFor(data) then
				return true
			end
			return false
		end
	end
	if completedMenuFor(data) then
		if closeMenuFor(data) then
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
	elseif tries > 0 and not menu.isOpen() then
		return true
	end
	return false
end

local function isPrepared(...)
	if tries == 0 then
		tries = {}
	end
	for i,name in ipairs(arg) do
		local currentCount = inventory.count(name)
		if currentCount > 0 then
			local previousCount = tries[name]
			if previousCount == nil or currentCount == previousCount then
				return false
			end
		end
	end
	return true
end

local function prepare(...)
	if tries == 0 then
		tries = {}
	end
	local item
	for idx,name in ipairs(arg) do
		local currentCount = inventory.count(name)
		local needsItem = currentCount > 0
		local previousCount = tries[name]
		if previousCount == nil then
			tries[name] = currentCount
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

-- DSum

local function nidoranDSum(disabled)
	local sx, sy = player.position()
	if not disabled and tries == nil then
		local opName = battle.opponent()
		local opLevel = memory.value("battle", "opponent_level")
		if opName == "rattata" then
			if opLevel == 2 then
				tries = {0, 4, 12}
			elseif opLevel == 3 then
				tries = {0, 14, 11}
			else
				-- tries = {0, 0, 10} -- TODO can't escape
			end
		elseif opName == "spearow" then
			if opLevel == 5 then
				-- can't escape
			end
		elseif opName == "nidoran" then
			tries = {0, 6, 12}
		elseif opName == "nidoranf" then
			if opLevel == 3 then
				tries = {4, 6, 12}
			else
				tries = {5, 6, 12}
			end
		end
		if tries then
			tries.idx = 1
			tries.x, tries.y = sx, sy
		else
			tries = 0
		end
	end
	if not disabled and tries ~= 0 then
		if tries[tries.idx] == 0 then
			tries.idx = tries.idx + 1
			if tries.idx > 3 then
				tries = 0
			end
			return nidoranDSum()
		end
		if tries.x ~= sx or tries.y ~= sy then
			tries[tries.idx] = tries[tries.idx] - 1
			tries.x, tries.y = sx, sy
		end
		if tries.idx == 2 then
			sy = 11
		else
			sy = 12
		end
	else
		sy = 11
	end
	if sx == 33 then
		sx = 32
	else
		sx = 33
	end
	walk.step(sx, sy)
end

-- Strategies

local strategyFunctions
strategyFunctions = {

	a = function(data)
		areaName = data.a
		return true
	end,

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

	tweetMisty = function()
		local elt = utils.elapsedTime()
		if setYolo("misty") then
			print("Misty: "..elt)
		else
			local pbn = ""
			local pbTime = getTimeRequirement("misty") - 1.75
			if not overMinute(pbTime) then
				pbn = " (PB pace)"
			end
			bridge.tweet("Got a run going, just beat Misty "..elt.." in"..pbn.." http://www.twitch.tv/thepokebot")
		end
		return true
	end,

	tweetVictoryRoad = function()
		local elt = utils.elapsedTime()
		local pbn = ""
		if not overMinute(98) then -- TODO verify
			pbn = " (PB pace)"
		end
		local elt = utils.elapsedTime()
		bridge.tweet("Entering Victory Road at "..elt..pbn.." on our way to the Elite Four! http://www.twitch.tv/thepokebot")
		return true
	end,

	split = function(data)
		bridge.split(data and data.finished)
		if not INTERNAL then
			splitNumber = splitNumber + 1

			local timeDiff
			splitTime, timeDiff = utils.timeSince(splitTime)
			if timeDiff then
				print(splitNumber..". "..areaName..": "..utils.elapsedTime().." ("..timeDiff..")")
			end
		end
		return true
	end,

	wait = function()
		print("Please save state")
		input.press("Start", 9001)
	end,

	emuSpeed = function(data)
		-- client.speedmode = data.percent
		return true
	end,

-- Global

	interact = function(data)
		if battle.handleWild() then
			if battle.isActive() then
				return true
			end
			if textbox.isActive() then
				if tries > 0 then
					return true
				end
				tries = tries - 1
				input.cancel()
			elseif player.interact(data.dir) then
				tries = tries + 1
			end
		end
	end,

	confirm = function(data)
		if battle.handleWild() then
			if textbox.isActive() then
				tries = tries + 1
				input.cancel(data.type or "A")
			else
				if tries > 0 then
					return true
				end
				player.interact(data.dir)
			end
		end
	end,

	item = function(data)
		if battle.handleWild() then
			if data.full and not inventory.isFull() then
				if closeMenuFor(data) then
					return true
				end
				return false
			end
			return useItem(data)
		end
	end,

	potion = function(data)
		local curr_hp = pokemon.index(0, "hp")
		if curr_hp == 0 then
			return false
		end
		local toHP
		if yolo and data.yolo ~= nil then
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
		end
		if closeMenuFor(data) then
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
				tries = tries + 1
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
			return useItem({item="bicycle"})
		end
	end,

	fightXAccuracy = function()
		return prepare("x_accuracy")
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

-- Route

	squirtleIChooseYou = function()
		if pokemon.inParty("squirtle") then
			bridge.caught("squirtle")
			return true
		end
		if player.face("Up") then
			textbox.name("A")
		end
	end,

	fightBulbasaur = function()
		if tries < 9000 and pokemon.index(0, "level") == 6 then
			if tries > 200 then
				squirtleAtt = pokemon.index(0, "attack")
				squirtleDef = pokemon.index(0, "defense")
				squirtleSpd = pokemon.index(0, "speed")
				squirtleScl = pokemon.index(0, "special")
				if squirtleAtt < 11 and squirtleScl < 12 then
					return reset("Bad Squirtle - "..squirtleAtt.." attack, "..squirtleScl.." special")
				end
				tries = 9001
			else
				tries = tries + 1
			end
		end
		if battle.isActive() and memory.double("battle", "opponent_hp") > 0 and resetTime(getTimeRequirement("bulbasaur"), "kill Bulbasaur") then
			return true
		end
		return buffTo("tail_whip", 6)
	end,

	dodgePalletBoy = function()
		return dodgeUp(0x0223, 14, 14, 15, 7)
	end,

	shopViridianPokeballs = function()
		return shop.transaction{
			buy = {{name="pokeball", index=0, amount=8}}
		}
	end,

	catchNidoran = function()
		if not control.canCatch() then
			return true
		end
		local pokeballs = inventory.count("pokeball")
		local caught = memory.value("player", "party_size") - 1
		if pokeballs < 5 - caught * 2 then
			return reset("Ran too low on PokeBalls", pokeballs)
		end
		if battle.isActive() then
			local isNidoran = pokemon.isOpponent("nidoran")
			if isNidoran and memory.value("battle", "opponent_level") > 2 then
				if initialize() then
					bridge.pollForName()
				end
			end
			tries = nil
			if memory.value("menu", "text_input") == 240 then
				textbox.name()
			elseif memory.value("battle", "menu") == 95 then
				if isNidoran then
					input.press("A")
				else
					input.cancel()
				end
			elseif not control.shouldCatch() then
				if control.shouldFight() then
					battle.fight()
				else
					battle.run()
				end
			end
		else
			local noDSum
			pokemon.updateParty()
			local hasNidoran = pokemon.inParty("nidoran")
			if hasNidoran then
				if not tempDir then
					bridge.caught("nidoran")
					tempDir = true
				end
				if pokemon.getExp() > 205 then
					level4Nidoran = pokemon.info("nidoran", "level") == 4
					return true
				end
				noDSum = true
			end

			local timeLimit = getTimeRequirement("nidoran")
			local resetMessage
			if hasNidoran then
				resetMessage = "get an experience kill before Brock"
			else
				resetMessage = "find a Nidoran"
			end
			if resetTime(timeLimit, resetMessage) then
				return true
			end
			if not noDSum and overMinute(timeLimit - 0.25) then
				noDSum = true
			end
			nidoranDSum(noDSum)
		end
	end,

-- 1: NIDORAN

	dodgeViridianOldMan = function()
		return dodgeUp(0x0273, 18, 6, 17, 9)
	end,

	grabTreePotion = function()
		if initialize() then
			if pokemon.info("squirtle", "hp") > 15 or pokemon.info("spearow", "level") == 3 then
				return true
			end
		end
		if inventory.contains("potion") then
			return true
		end

		local px, py = player.position()
		if px > 15 then
			walk.step(15, 4)
		else
			player.interact("Left")
		end
	end,

	grabAntidote = function()
		local px, py = player.position()
		if py < 11 then
			return true
		end
		if pokemon.info("spearow", "level") == 3 then
			if px < 26 then
				px = 26
			else
				py = 10
			end
		elseif inventory.contains("antidote") then
			py = 10
		else
			player.interact("Up")
		end
		walk.step(px, py)
	end,

	grabForestPotion = function()
		if battle.handleWild() then
			if inventory.contains("potion") then
				local healthNeeded = (pokemon.info("spearow", "level") == 3) and 8 or 15
				if pokemon.info("squirtle", "hp") <= healthNeeded then
					if menu.pause() then
						inventory.use("potion", "squirtle")
					end
				else
					return true
				end
			elseif menu.close() then
				player.interact("Up")
			end
		end
	end,

	fightWeedle = function()
		if battle.isTrainer() then
			canProgress = true
			local squirtleOut = pokemon.isDeployed("squirtle")
			if squirtleOut and memory.value("battle", "our_status") > 0 and not inventory.contains("antidote") then
				return reset("Poisoned, but we skipped the antidote")
			end
			local sidx = pokemon.indexOf("spearow")
			if sidx ~= -1 and pokemon.index(sidx, "level") > 3 then
				sidx = -1
			end
			if sidx == -1 then
				return buffTo("tail_whip", 5)
			end
			if pokemon.index(sidx, "hp") < 1 then
				local battleMenu = memory.value("battle", "menu")
				if utils.onPokemonSelect(battleMenu) then
					menu.select(pokemon.indexOf("squirtle"), true)
				elseif battleMenu == 95 then
					input.press("A")
				elseif squirtleOut then
					battle.automate()
				else
					input.cancel()
				end
			elseif squirtleOut then
				battle.swap("spearow")
			else
				local peck = combat.bestMove()
				local forced
				if peck and peck.damage and peck.damage + 1 >= memory.double("battle", "opponent_hp") then
					forced = "growl"
				end
				battle.fight(forced)
			end
		elseif canProgress then
			return true
		end
	end,

	equipForBrock = function(data)
		if initialize() then
			if pokemon.info("squirtle", "level") < 8 then
				return reset("Not level 8 before Brock", pokemon.getExp())
			end
			if data.anti then
				local poisoned = pokemon.info("squirtle", "status") > 0
				if not poisoned then
					return true
				end
				if not inventory.contains("antidote") then
					return reset("Poisoned, but we skipped the antidote")
				end
				local curr_hp = pokemon.info("squirtle", "hp")
				if inventory.contains("potion") and curr_hp > 8 and curr_hp < 18 then
					return true
				end
			end
		end
		local main = memory.value("menu", "main")
		local nidoranIndex = pokemon.indexOf("nidoran")
		if nidoranIndex == 0 then
			if menu.close() then
				return true
			end
		elseif menu.pause() then
			local column = menu.getCol()
			if pokemon.info("squirtle", "status") > 0 then
				inventory.use("antidote", "squirtle")
			elseif inventory.contains("potion") and pokemon.info("squirtle", "hp") < 15 then
				inventory.use("potion", "squirtle")
			else
				if main == 128 then
					if column == 11 then
						menu.select(1, true)
					elseif column == 12 then
						menu.select(1, true)
					else
						input.press("B")
					end
				elseif main == 103 then
					if memory.value("menu", "selection_mode") == 1 then
						menu.select(nidoranIndex, true)
					else
						menu.select(0, true)
					end
				else
					input.press("B")
				end
			end
		end
	end,

	fightBrock = function()
		local squirtleHP = pokemon.info("squirtle", "hp")
		if squirtleHP == 0 then
			return resetDeath()
		end
		if battle.isActive() then
			if tries < 1 then
				tries = 1
			end
			local bubble, turnsToKill, turnsToDie = combat.bestMove()
			if not pokemon.isDeployed("squirtle") then
				battle.swap("squirtle")
			elseif turnsToDie and turnsToDie < 2 and inventory.contains("potion") then
				inventory.use("potion", "squirtle", true)
			else
				local battleMenu = memory.value("battle", "menu")
				local bideTurns = memory.value("battle", "opponent_bide")
				if battleMenu == 95 and menu.getCol() == 1 then
					input.press("A")
				elseif bideTurns > 0 then
					local onixHP = memory.double("battle", "opponent_hp")
					if not canProgress then
						canProgress = onixHP
						tempDir = bideTurns
					end
					if turnsToKill then
						local forced
						if turnsToDie < 2 or turnsToKill < 2 or tempDir - bideTurns > 1 then
						-- elseif turnsToKill < 3 and tempDir == bideTurns then
						elseif onixHP == canProgress then
							forced = "tail_whip"
						end
						battle.fight(forced)
					else
						input.cancel()
					end
				elseif utils.onPokemonSelect(battleMenu) then
					menu.select(pokemon.indexOf("nidoran"), true)
				else
					canProgress = false
					battle.fight()
				end
				if tries < 9000 then
					local nidx = pokemon.indexOf("nidoran")
					if pokemon.index(nidx, "level") == 8 then
						local att = pokemon.index(nidx, "attack")
						local def = pokemon.index(nidx, "defense")
						local spd = pokemon.index(nidx, "speed")
						local scl = pokemon.index(nidx, "special")
						bridge.stats(att.." "..def.." "..spd.." "..scl)
						nidoAttack = att
						nidoSpeed = spd
						nidoSpecial = scl
						if tries > 300 then
							local statDiff = (16 - att) + (15 - spd) + (13 - scl)
							if def < 12 then
								statDiff = statDiff + 1
							end
							if not level4Nidoran then
								statDiff = statDiff + 1
							end
							local resets = att < 15 or spd < 14 or scl < 12 or statDiff > 3 or (att == 15 and spd == 14)
							local nStatus = "Att: "..att..", Def: "..def..", Speed: "..spd..", Special: "..scl
							if resets then
								return reset("Bad Nidoran - "..nStatus)
							end
							tries = 9001
							local superlative
							local exclaim = "!"
							if statDiff == 0 then
								if def == 14 then
									superlative = " god"
									exclaim = "! Kreygasm"
								else
									superlative = " perfect"
								end
							elseif att == 16 and spd == 15 then
								if statDiff == 1 then
									superlative = " great"
								elseif statDiff == 2 then
									superlative = " good"
								else
									superlative = " okay"
								end
							elseif statDiff == 1 then
								superlative = " good"
							elseif statDiff == 2 then
								superlative = "n okay"
								exclaim = "."
							else
								superlative = " min stat"
								exclaim = "."
							end
							nStatus = "Beat Brock with a"..superlative.." Nidoran"..exclaim.." "..nStatus..", caught at level "..(level4Nidoran and "4" or "3").."."
							bridge.chat(nStatus)
						else
							tries = tries + 1
						end
					end
				end
			end
		elseif tries > 0 then
			return true
		elseif textbox.handle() then
			player.interact("Up")
		end
	end,

-- 2: BROCK

	shopPewterMart = function()
		return shop.transaction{
			buy = {{name="potion", index=1, amount=9}}
		}
	end,

	battleModeSet = function()
		if memory.value("setting", "battle_style") == 10 then
			if menu.close() then
				return true
			end
		elseif menu.pause() then
			local main = memory.value("menu", "main")
			if main == 128 then
				if menu.getCol() ~= 11 then
					input.press("B")
				else
					menu.select(5, true)
				end
			elseif main == 228 then
				menu.setOption("battle_style", 8, 10)
			else
				input.press("B")
			end
		end
	end,

	leer = function(data)
		local bm = combat.bestMove()
		if not bm or bm.minTurns < 3 then
			if battle.isActive() then
				canProgress = true
			elseif canProgress then
				return true
			end
			battle.automate()
			return false
		end
		local opp = battle.opponent()
		local defLimit = 9001
		for i,poke in ipairs(data) do
			if opp == poke[1] then
				local minimumAttack = poke[3]
				if not minimumAttack or nidoAttack > minimumAttack then
					defLimit = poke[2]
				end
				break
			end
		end
		return buffTo("leer", defLimit)
	end,

	bugCatcher = function()
		if battle.isActive() then
			canProgress = true
			local isWeedle = pokemon.isOpponent("weedle")
			if isWeedle and not tempDir then
				tempDir = true
			end
			secondCaterpie = tempDir
			if not isWeedle and secondCaterpie then
				if level4Nidoran and nidoSpeed >= 14 and pokemon.index(0, "attack") >= 19 then
					-- print("IA "..pokemon.index(0, "attack"))
					battle.automate()
					return
				end
			end
			strategyFunctions.leer({{"caterpie",8}, {"weedle",7}})
		elseif canProgress then
			return true
		else
			battle.automate()
		end
	end,

	shortsKid = function()
		local fightingEkans = pokemon.isOpponent("ekans")
		if fightingEkans then
			local wrapping = memory.value("battle", "turns") > 0
			if wrapping then
				local curr_hp = memory.double("battle", "our_hp")
				if not tempDir then
					tempDir = curr_hp
				end
				local wrapDamage = tempDir - curr_hp
				if wrapDamage > 0 and wrapDamage < 7 and curr_hp < 14 and not opponentDamaged() then
					inventory.use("potion", nil, true)
					return false
				end
			elseif tempDir then
				tempDir = nil
			end
		end
		control.battlePotion(fightingEkans or damaged(2))
		return strategyFunctions.leer({{"rattata",9}, {"ekans",10}})
	end,

	potionBeforeCocoons = function()
		if nidoSpeed >= 15 then
			return true
		end
		return strategyFunctions.potion({hp=6, yolo=3})
	end,

	swapHornAttack = function()
		if pokemon.battleMove("horn_attack") == 1 then
			return true
		end
		battle.swapMove(1, 3)
	end,

	fightMetapod = function()
		if battle.isActive() then
			canProgress = true
			if memory.double("battle", "opponent_hp") > 0 and pokemon.isOpponent("metapod") then
				return true
			end
			battle.automate()
		elseif canProgress then
			return true
		else
			battle.automate()
		end
	end,

	catchFlierBackup = function()
		if initialize() then
			control.canDie(true)
		end
		if not control.canCatch() then
			return true
		end
		local caught = pokemon.inParty("pidgey", "spearow")
		if battle.isActive() then
			if memory.double("battle", "our_hp") == 0 then
				if pokemon.info("squirtle", "hp") == 0 then
					control.canDie(false)
				elseif utils.onPokemonSelect(memory.value("battle", "menu")) then
					menu.select(pokemon.indexOf("squirtle"), true)
				else
					input.press("A")
				end
			elseif not control.shouldCatch() then
				battle.run()
			end
		else
			local birdPath
			local px, py = player.position()
			if caught then
				if px > 33 then
					return true
				end
				local startY = 9
				if px > 28 then
					startY = py
				end
				birdPath = {{32,startY}, {32,11}, {34,11}}
			elseif px == 37 then
				if py == 10 then
					py = 11
				else
					py = 10
				end
				walk.step(px, py)
			else
				birdPath = {{32,10}, {32,11}, {34,11}, {34,10}, {37,10}}
			end
			if birdPath then
				walk.custom(birdPath)
			end
		end
	end,

-- 3: ROUTE 3

	startMtMoon = function()
		strategies.moonEncounters = 0
		control.canDie(false)
		return true
	end,

	evolveNidorino = function()
		if pokemon.inParty("nidorino") then
			bridge.caught("nidorino")
			return true
		end
		if battle.isActive() then
			tries = 0
			canProgress = true
			if memory.double("battle", "opponent_hp") == 0 then
				input.press("A")
			else
				battle.automate()
			end
		elseif tries > 3600 then
			print("Broke from Nidorino on tries")
			return true
		else
			if canProgress then
				tries = tries + 1
			end
			input.press("A")
		end
	end,

	evolveNidoking = function()
		if battle.handleWild() then
			if not inventory.contains("moon_stone") then
				if initialize() then
					bridge.caught("nidoking")
				end
				if menu.close() then
					return true
				end
			elseif not inventory.use("moon_stone") then
				menu.pause()
			end
		end
	end,

	helix = function()
		if battle.handleWild() then
			if inventory.contains("helix_fossil") then
				return true
			end
			player.interact("Up")
		end
	end,

	reportMtMoon = function()
		if battle.pp("horn_attack") == 0 then
			print("ERR: Ran out of Horn Attacks")
		end
		if strategies.moonEncounters then
			local parasStatus
			local conjunction = "but"
			local goodEncounters = strategies.moonEncounters < 10
			local parasCatch
			if pokemon.inParty("paras") then
				parasCatch = "paras"
				if goodEncounters then
					conjunction = "and"
				end
				parasStatus = "we found a Paras!"
			else
				parasCatch = "no_paras"
				if not goodEncounters then
					conjunction = "and"
				end
				parasStatus = "we didn't find a Paras :("
			end
			bridge.caught(parasCatch)
			bridge.chat(strategies.moonEncounters.." Moon encounters, "..conjunction.." "..parasStatus)
			strategies.moonEncounters = nil
		end

		local timeLimit = getTimeRequirement("mt_moon")
		resetTime(timeLimit, "complete Mt. Moon", true)
		return true
	end,

-- 4: MT. MOON

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

	rivalSandAttack = function(data)
		if battle.isActive() then
			if battle.redeployNidoking() then
				return false
			end

			local opponent = battle.opponent()
			if opponent == "pidgeotto" then
				canProgress = true
				combat.disableThrash = true
				if memory.value("battle", "accuracy") < 7 then
					local __, turns = combat.bestMove()
					if turns == 1 and battle.sacrifice("pidgey", "spearow", "paras", "oddish", "squirtle") then
						return false
					end
				end
			elseif opponent == "raticate" then
				combat.disableThrash = opponentDamaged() or (not yolo and pokemon.index(0, "hp") < 32) -- RISK
			elseif opponent == "ivysaur" then
				if not yolo and damaged(5) and inventory.contains("super_potion") then
					inventory.use("super_potion", nil, true)
					return false
				end
				combat.disableThrash = opponentDamaged()
			else
				combat.disableThrash = false
			end
			battle.automate()
			canProgress = true
		elseif canProgress then
			combat.disableThrash = false
			return true
		else
			textbox.handle()
		end
	end,

	teachThrash = function()
		if initialize() then
			if pokemon.hasMove("thrash") or pokemon.info("nidoking", "level") < 21 then
				return true
			end
		end
		if strategyFunctions.teach({move="thrash",item="rare_candy",replace="leer"}) then
			if menu.close() then
				local att = pokemon.index(0, "attack")
				local def = pokemon.index(0, "defense")
				local spd = pokemon.index(0, "speed")
				local scl = pokemon.index(0, "special")
				local statDesc = att.." "..def.." "..spd.." "..scl
				nidoAttack = att
				nidoSpeed = spd
				nidoSpecial = scl
				bridge.stats(statDesc)
				print(statDesc)
				return true
			end
		end
	end,

	redbarMankey = function()
		if not setYolo("mankey") then
			return true
		end
		local curr_hp, red_hp = pokemon.index(0, "hp"), redHP()
		if curr_hp <= red_hp then
			return true
		end
		if initialize() then
			if pokemon.info("nidoking", "level") < 23 or inventory.count("potion") < 3 then -- RISK
				return true
			end
			bridge.chat("Using Poison Sting to attempt to redbar off Mankey")
		end
		if battle.isActive() then
			canProgress = true
			local enemyMove, enemyTurns = combat.enemyAttack()
			if enemyTurns then
				if enemyTurns < 2 then
					return true
				end
				local scratchDmg = enemyMove.damage
				if curr_hp - red_hp > scratchDmg then
					return true
				end
			end
			battle.automate("poison_sting")
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	thrashGeodude = function()
		if battle.isActive() then
			canProgress = true
			if pokemon.isOpponent("geodude") and pokemon.isDeployed("nidoking") then
				if battle.sacrifice("squirtle") then
					return false
				end
			end
			battle.automate()
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	potionBeforeGoldeen = function()
		if initialize() then
			if setYolo("goldeen") or pokemon.index(0, "hp") > 7 then
				return true
			end
		end
		return strategyFunctions.potion({hp=64, chain=true})
	end,

	potionBeforeMisty = function()
		local healAmount = 70
		if yolo then
			if nidoAttack > 53 and nidoSpeed > 50 then
				healAmount = 45
			elseif nidoAttack > 53 then
				healAmount = 65
			end
		else
			if nidoAttack > 53 and nidoSpeed > 51 then -- RISK
				healAmount = 45
			elseif nidoAttack > 53 and nidoSpeed > 50 then
				healAmount = 65
			end
		end
		if initialize() then
			if healAmount < 60 then
				bridge.chat("Limiting heals to attempt to get closer to red-bar off Misty", inventory.count("potion"))
			end
		end
		return strategyFunctions.potion({hp=healAmount})
	end,

	fightMisty = function()
		if battle.isActive() then
			canProgress = true
			if battle.redeployNidoking() then
				if tempDir == false then
					tempDir = true
				end
				return false
			end
			local swappedOut = tempDir
			if not swappedOut and combat.isConfused() then
				tempDir = false
				if battle.sacrifice("pidgey", "spearow", "paras") then
					return false
				end
			end
			battle.automate()
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

-- 6: MISTY

	potionBeforeRocket = function()
		local minAttack = 55 -- RISK
		if yolo then
			minAttack = minAttack - 1
		end
		if nidoAttack >= minAttack then
			return true
		end
		return strategyFunctions.potion({hp=10})
	end,

	jingleSkip = function()
		if canProgress then
			local px, py = player.position()
			if px < 4 then
				return true
			end
			input.press("Left", 0)
		else
			input.press("A", 0)
			canProgress = true
		end
	end,

	catchOddish = function()
		if not control.canCatch() then
			return true
		end
		local caught = pokemon.inParty("oddish", "paras")
		local battleValue = memory.value("game", "battle")
		local px, py = player.position()
		if battleValue > 0 then
			if battleValue == 2 then
				tries = 2
				battle.automate()
			else
				if tries == 0 and py == 31 then
					tries = 1
				end
				if not control.shouldCatch() then
					battle.run()
				end
			end
		elseif tries == 1 and py == 31 then
			player.interact("Left")
		else
			local path
			if caught then
				if not tempDir then
					bridge.caught(pokemon.inParty("oddish"))
					tempDir = true
				end
				if py < 21 then
					py = 21
				elseif py < 24 then
					if px < 16 then
						px = 17
					else
						py = 24
					end
				elseif py < 25 then
					py = 25
				elseif px > 15 then
					px = 15
				elseif py < 28 then
					py = 28
				elseif py > 29 then
					py = 29
				elseif px ~= 11 then
					px = 11
				elseif py ~= 29 then
					py = 29
				else
					return true
				end
				walk.step(px, py)
			elseif px == 12 then
				local dy
				if py == 30 then
					dy = 31
				else
					dy = 30
				end
				walk.step(px, dy)
			else
				local path = {{15,19}, {15,25}, {15,25}, {15,27}, {14,27}, {14,30}, {12,30}}
				walk.custom(path)
			end
		end
	end,

	shopVermilionMart = function()
		if initialize() then
			setYolo("vermilion")
		end
		local buyArray, sellArray
		if not inventory.contains("pokeball") or (not yolo and nidoAttack < 53) then
			sellArray = {{name="pokeball"}, {name="antidote"}, {name="tm34"}, {name="nugget"}}
			buyArray = {{name="super_potion",index=1,amount=3}, {name="paralyze_heal",index=4,amount=2}, {name="repel",index=5,amount=3}}
		else
			sellArray = {{name="antidote"}, {name="tm34"}, {name="nugget"}}
			buyArray = {{name="super_potion",index=1,amount=3}, {name="repel",index=5,amount=3}}
		end
		return shop.transaction{
			sell = sellArray,
			buy = buyArray
		}
	end,

	-- rivalSandAttack

	trashcans = function()
		local progress = memory.value("progress", "trashcans")
		if textbox.isActive() then
			if not canProgress then
				if progress < 2 then
					tries = tries + 1
				end
				canProgress = true
			end
			input.cancel()
		else
			if progress == 3 then
				local px, py = player.position()
				if px == 4 and py == 6 then
					tries = tries + 1
					local timeLimit = getTimeRequirement("trash") + 1
					if resetTime(timeLimit, "complete Trashcans ("..tries.." tries)") then
						return true
					end
					setYolo("trash")

					local prefix
					local suffix = "!"
					if tries < 2 then
						prefix = "PERFECT"
					elseif tries < 4 then
						prefix = "Amazing"
					elseif tries < 7 then
						prefix = "Great"
					elseif tries < 10 then
						prefix = "Good"
					elseif tries < 24 then
						prefix = "Ugh"
						suffix = "."
					else -- TODO trashcans WR
						prefix = "Reset me now"
						suffix = " BibleThump"
					end
					bridge.chat(prefix..", "..tries.." try Trashcans"..suffix, utils.elapsedTime())
					return true
				end
				local completePath = {
					Down = {{2,11}, {8,7}},
					Right = {{2,12}, {3,12}, {2,6}, {3,6}},
					Left = {{9,8}, {8,8}, {7,8}, {6,8}, {5,8}, {9,10}, {8,10}, {7,10}, {6,10}, {5,10}, {}, {}, {}, {}, {}, {}},
				}
				local walkIn = "Up"
				for dir,tileset in pairs(completePath) do
					for i,tile in ipairs(tileset) do
						if px == tile[1] and py == tile[2] then
							walkIn = dir
							break
						end
					end
				end
				input.press(walkIn, 0)
			elseif progress == 2 then
				if canProgress then
					canProgress = false
					walk.invertCustom()
				end
				local inverse = {
					Up = "Down",
					Right = "Left",
					Down = "Up",
					Left = "Right"
				}
				player.interact(inverse[tempDir])
			else
				local trashPath = {{2,11},{"Left"},{2,11}, {2,12},{4,12},{4,11},{"Right"},{4,11}, {4,9},{"Left"},{4,9}, {4,7},{"Right"},{4,7}, {4,6},{2,6},{2,7},{"Left"},{2,7}, {2,6},{4,6},{4,8},{7,8},{"Down"},{7,8}, {9,8},{"Up"},{9,8}, {8,8},{8,11},{"Right"},{8,11}}
				if tempDir and type(tempDir) == "number" then
					local px, py = player.position()
					local dx, dy = px, py
					if py < 12 then
						dy = 12
					elseif tempDir == 1 then
						dx = 2
					else
						dx = 8
					end
					if px ~= dx or py ~= dy then
						walk.step(dx, dy)
						return
					end
					tempDir = nil
				end
				tempDir = walk.custom(trashPath, canProgress)
				canProgress = false
			end
		end
	end,

	fightSurge = function()
		if battle.isActive() then
			canProgress = true
			local forced
			if pokemon.isOpponent("voltorb") then
				combat.disableThrash = true
				local __, enemyTurns = combat.enemyAttack()
				if not enemyTurns or enemyTurns > 2 then
					forced = "bubblebeam"
				elseif enemyTurns == 2 and not opponentDamaged() then
					local curr_hp, red_hp = pokemon.index(0, "hp"), redHP()
					local afterHit = curr_hp - 20
					if afterHit > 5 and afterHit <= red_hp then
						forced = "bubblebeam"
					end
				end
			else
				combat.disableThrash = false
			end
			battle.automate(forced)
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

-- 7: SURGE

	procureBicycle = function()
		if inventory.contains("bicycle") then
			if not textbox.isActive() then
				return true
			end
			input.cancel()
		elseif textbox.handle() then
			player.interact("Right")
		end
	end,

	swapBicycle = function()
		local bicycleIdx = inventory.indexOf("bicycle")
		if bicycleIdx < 3 then
			return true
		end
		local main = memory.value("menu", "main")
		if main == 128 then
			if menu.getCol() ~= 5 then
				menu.select(2, true)
			else
				local selection = memory.value("menu", "selection_mode")
				if selection == 0 then
					if menu.select(0, "accelerate", true, nil, true) then
						input.press("Select")
					end
				else
					if menu.select(bicycleIdx, "accelerate", true, nil, true) then
						input.press("Select")
					end
				end
			end
		else
			menu.pause()
		end
	end,

	redbarCubone = function()
		if battle.isActive() then
			local forced
			canProgress = true
			if pokemon.isOpponent("cubone") then
				local enemyMove, enemyTurns = combat.enemyAttack()
				if enemyTurns then
					local curr_hp, red_hp = pokemon.index(0, "hp"), redHP()
					local clubDmg = enemyMove.damage
					local afterHit = curr_hp - clubDmg
					red_hp = red_hp - 2
					if afterHit > -2 and afterHit < red_hp then
						forced = "thunderbolt"
					else
						afterHit = afterHit - clubDmg
						if afterHit > 1 and afterHit < red_hp then
							forced = "thunderbolt"
						end
					end
					if forced and initialize() then
						bridge.chat("Using Thunderbolt to attempt to redbar off Cubone")
					end
				end
			end
			battle.automate(forced)
		elseif canProgress then
			return true
		else
			battle.automate()
		end
	end,

	shopTM07 = function()
		return shop.transaction{
			direction = "Up",
			buy = {{name="horn_drill", index=3}}
		}
	end,

	shopRepels = function()
		return shop.transaction{
			direction = "Up",
			buy = {{name="super_repel", index=3, amount=9}}
		}
	end,

	shopPokeDoll = function()
		return shop.transaction{
			direction = "Down",
			buy = {{name="pokedoll", index=0}}
		}
	end,

	shopVending = function()
		return shop.vend{
			direction = "Up",
			buy = {{name="fresh_water", index=0}, {name="soda_pop", index=1}}
		}
	end,

	giveWater = function()
		if not inventory.contains("fresh_water", "soda_pop") then
			return true
		end
		if textbox.isActive() then
			input.cancel("A")
		else
			local cx, cy = memory.raw(0x0223) - 3, memory.raw(0x0222) - 3
			local px, py = player.position()
			if utils.dist(cx, cy, px, py) == 1 then
				player.interact(walk.dir(px, py, cx, cy))
			else
				walk.step(cx, cy)
			end
		end
	end,

	shopExtraWater = function()
		return shop.vend{
			direction = "Up",
			buy = {{name="fresh_water", index=0}}
		}
	end,

	shopBuffs = function()
		if initialize() then
			local minSpecial = 45
			if yolo then
				minSpecial = minSpecial - 1
			end
			if nidoAttack >= 54 and nidoSpecial >= minSpecial then
				riskGiovanni = true
				print("Giovanni skip strats!")
			end
		end

		local xspecAmt = 4
		if riskGiovanni then
			xspecAmt = xspecAmt + 1
		elseif nidoSpecial < 46 then
			-- xspecAmt = xspecAmt - 1
		end
		return shop.transaction{
			direction = "Up",
			buy = {{name="x_accuracy", index=0, amount=10}, {name="x_speed", index=5, amount=4}, {name="x_special", index=6, amount=xspecAmt}}
		}
	end,

	deptElevator = function()
		if textbox.isActive() then
			canProgress = true
			menu.select(0, false)
		else
			if canProgress then
				return true
			end
			player.interact("Up")
		end
	end,

	swapRepels = function()
		local repelIdx = inventory.indexOf("super_repel")
		if repelIdx < 3 then
			return true
		end
		local main = memory.value("menu", "main")
		if main == 128 then
			if menu.getCol() ~= 5 then
				menu.select(2, true)
			else
				local selection = memory.value("menu", "selection_mode")
				if selection == 0 then
					if menu.select(1, "accelerate", true, nil, true) then
						input.press("Select")
					end
				else
					if menu.select(repelIdx, "accelerate", true, nil, true) then
						input.press("Select")
					end
				end
			end
		else
			menu.pause()
		end
	end,

-- 8: FLY

	lavenderRival = function()
		if battle.isActive() then
			canProgress = true
			local forced
			if nidoSpecial > 44 then -- RISK
				local __, enemyTurns = combat.enemyAttack()
				if enemyTurns and enemyTurns < 2 and pokemon.isOpponent("pidgeotto", "gyarados") then
					battle.automate()
					return false
				end
			end
			if pokemon.isOpponent("gyarados") or prepare("x_accuracy") then
				battle.automate()
			end
		elseif canProgress then
			return true
		else
			input.cancel()
		end
	end,

	pokeDoll = function()
		if battle.isActive() then
			canProgress = true
			inventory.use("pokedoll", nil, true)
		elseif canProgress then
			return true
		else
			input.cancel()
		end
	end,

	digFight = function()
		if battle.isActive() then
			canProgress = true
			local backupIndex = pokemon.indexOf("paras", "squirtle")
			if pokemon.isDeployed("nidoking") then
				if pokemon.info("nidoking", "hp") == 0 then
					if utils.onPokemonSelect(memory.value("battle", "menu")) then
						menu.select(backupIndex, true)
					else
						input.press("A")
					end
				else
					battle.automate()
				end
			elseif pokemon.info("nidoking", "hp") == 0 and pokemon.index(backupIndex, "hp") == 0 and pokemon.isDeployed("paras", "squirtle") then
				return resetDeath()
			else
				battle.fight("dig")
			end
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	thunderboltFirst = function()
		local forced
		if pokemon.isOpponent("zubat") then
			canProgress = true
			forced = "thunderbolt"
		elseif canProgress then
			return true
		end
		battle.automate(forced)
	end,

-- 8: POKÉFLUTE

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

	drivebyRareCandy = function()
		if textbox.isActive() then
			canProgress = true
			input.cancel()
		elseif canProgress then
			return true
		else
			local px, py = player.position()
			if py < 13 then
				tries = 0
				return
			end
			if py == 13 and tries % 2 == 0 then
				input.press("A", 2)
			else
				input.press("Up")
				tries = 0
			end
			tries = tries + 1
		end
	end,

	safariCarbos = function()
		if initialize() then
			setYolo("safari_carbos")
		end
		local minSpeed = 50
		if yolo then
			minSpeed = minSpeed - 1
		end
		if nidoSpeed >= minSpeed then
			return true
		end
		if inventory.contains("carbos") then
			if walk.step(20, 20) then
				return true
			end
		else
			local px, py = player.position()
			if px < 21 then
				walk.step(21, py)
			elseif px == 21 and py == 13 then
				player.interact("Left")
			else
				walk.step(21, 13)
			end
		end
	end,

	centerSkipFullRestore = function()
		if initialize() then
			if yolo or inventory.contains("full_restore") then
				return true
			end
			bridge.chat("We need to grab the backup Full Restore here.")
		end
		local px, py = player.position()
		if px < 21 then
			px = 21
		elseif py < 9 then
			py = 9
		else
			return strategyFunctions.interact({dir="Down"})
		end
		walk.step(px, py)
	end,

	silphElevator = function()
		if textbox.isActive() then
			canProgress = true
			menu.select(9, false, true)
		else
			if canProgress then
				return true
			end
			player.interact("Up")
		end
	end,

	fightSilphMachoke = function()
		if battle.isActive() then
			canProgress = true
			if nidoSpecial > 44 then
				return prepare("x_accuracy")
			end
			battle.automate("thrash")
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	silphCarbos = function()
		if nidoSpeed > 50 then
			return true
		end
		return strategyFunctions.interact({dir="Left"})
	end,

	silphRival = function()
		if battle.isActive() then
			if initialize() then
				tempDir = combat.healthFor("RivalGyarados")
				print("Gyarados "..tempDir)
				canProgress = true
			end
			local gyaradosDamage = tempDir

			local forced
			local readyToAttack = false
			local opName = battle.opponent()
			if opName == "gyarados" then
				readyToAttack = true
				local hp, red_hp = pokemon.index(0, "hp"), redHP()
				if hp > gyaradosDamage * 0.98 and hp - gyaradosDamage * 0.975 < red_hp then --TODO
					if prepare("x_special") then
						forced = "ice_beam"
					else
						readyToAttack = false
					end
				elseif isPrepared("x_special") then
					local canPotion
					if inventory.contains("potion") and hp + 20 > gyaradosDamage and hp + 20 - gyaradosDamage < red_hp then
						canPotion = "potion"
					elseif inventory.contains("super_potion") and hp + 50 > gyaradosDamage and hp + 50 - gyaradosDamage < red_hp then
						canPotion = "super_potion"
					end
					if canPotion then
						inventory.use(canPotion, nil, true)
						readyToAttack = false
					end
				end
			elseif prepare("x_accuracy", "x_speed") then
				if opName == "pidgeot" then
					if riskGiovanni or nidoSpecial < 45 or pokemon.info("nidoking", "hp") > 85 then
						forced = "thunderbolt"
					end
				elseif opName == "alakazam" or opName == "growlithe" then
					forced = "earthquake"
				end
				readyToAttack = true
			end
			if readyToAttack then
				battle.automate(forced)
			end
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	fightSilphGiovanni = function()
		if battle.isActive() then
			canProgress = true
			local forced
			if pokemon.isOpponent("nidorino") then
				if battle.pp("horn_drill") > 2 then
					forced = "horn_drill"
				else
					forced = "earthquake"
				end
			elseif pokemon.isOpponent("rhyhorn") then
				forced = "ice_beam"
			elseif pokemon.isOpponent("kangaskhan") then
				forced = "horn_drill"
			end
			battle.automate(forced)
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

--	9: SILPH CO.

	healBeforeHypno = function()
		local curr_hp, red_hp = pokemon.index(0, "hp"), redHP()
		local healthUnderRedBar = red_hp - curr_hp
		local yoloHP = combat.healthFor("HypnoHeadbutt") * 0.9
		local healTarget
		local rareCandyCount = inventory.count("rare_candy")
		local useRareCandy
		if healthUnderRedBar >= 0 then
			healTarget = "HypnoHeadbutt"
			if healthUnderRedBar > 2 then
				if rareCandyCount > 2 then
					useRareCandy = true
				end
			end
		else
			healTarget = "HypnoConfusion"
			useRareCandy = rareCandyCount > 2
		end
		if useRareCandy and curr_hp < combat.healthFor("KogaWeezing") * 0.85 then
			if menu.pause() then
				inventory.use("rare_candy", nil, false)
			end
			return false
		end

		return strategyFunctions.potion({hp=healTarget, yolo=yoloHP, close=true})
	end,

	fightHypno = function()
		if battle.isActive() then
			local forced
			if pokemon.isOpponent("hypno") then
				if pokemon.info("nidoking", "hp") > combat.healthFor("KogaWeezing") * 0.9 then
					if combat.isDisabled(85) then
						forced = "ice_beam"
					else
						forced = "thunderbolt"
					end
				end
			end
			battle.automate(forced)
			canProgress = true
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	fightKoga = function() --TODO x-accuracy?
		if battle.isActive() then
			local forced
			if pokemon.isOpponent("weezing") then
				if opponentDamaged(2) then
					inventory.use("pokeflute", nil, true)
					return false
				end
				forced = "thunderbolt"
				control.canDie(true)
			end
			battle.fight(forced)
			canProgress = true
		elseif canProgress then
			deepRun = true
			return true
		else
			textbox.handle()
		end
	end,

-- 10: KOGA

	dodgeGirl = function()
		local gx, gy = memory.raw(0x0223) - 5, memory.raw(0x0222)
		local px, py = player.position()
		if py > gy then
			if px > 3 then
				px = 3
			else
				return true
			end
		elseif gy - py ~= 1 or px ~= gx then
			py = py + 1
		elseif px == 3 then
			px = 2
		else
			px = 3
		end
		walk.step(px, py)
	end,

	cinnabarCarbos = function()
		local px, py = player.position()
		if px == 21 then
			return true
		end
		local minSpeed = 51
		if yolo then
			minSpeed = minSpeed - 1
		end
		if nidoSpeed > minSpeed then -- TODO >=
			walk.step(21, 20)
		else
			if py == 20 then
				py = 21
			elseif px == 17 and not inventory.contains("carbos") then
				player.interact("Right")
				return false
			else
				px = 21
			end
			walk.step(px, py)
		end
	end,

	fightErika = function()
		if battle.isActive() then
			canProgress = true
			local forced
			local curr_hp, red_hp = pokemon.index(0, "hp"), redHP()
			local razorDamage = 34
			if curr_hp > razorDamage and curr_hp - razorDamage < red_hp then
				if opponentDamaged() then
					forced = "thunderbolt"
				elseif nidoSpecial < 45 then
					forced = "ice_beam"
				else
					forced = "thunderbolt"
				end
			elseif riskGiovanni then
				forced = "ice_beam"
			end
			battle.automate(forced)
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

-- 11: ERIKA

	waitToReceive = function()
		local main = memory.value("menu", "main")
		if main == 128 then
			if canProgress then
				return true
			end
		elseif main == 32 or main == 123 then
			canProgress = true
			input.cancel()
		else
			input.press("Start", 2)
		end
	end,

-- 14: SABRINA

	earthquakeElixer = function(data)
		if battle.pp("earthquake") >= data.min then
			if closeMenuFor(data) then
				return true
			end
			return false
		end
		if initialize() then
			if areaName then
				print("EQ Elixer: "..areaName)
			end
		end
		return useItem({item="elixer", poke="nidoking", chain=data.chain, close=data.close})
	end,

	fightGiovanniMachoke = function()
		if initialize() then
			if nidoAttack >= 55 then
				local eqRequired = nidoSpecial >= 47 and 7 or 8
				if battle.pp("earthquake") >= eqRequired then
					bridge.chat("Using Earthquake strats on the Machokes")
					return true
				end
			end
		end
		return prepare("x_special")
	end,

	checkGiovanni = function()
		local ryhornDamage = math.floor(combat.healthFor("GiovanniRhyhorn") * 0.9)
		if initialize() then
			local earthquakePP = battle.pp("earthquake")
			if earthquakePP >= 2 then
				if riskGiovanni then
					if earthquakePP >= 5 then
						bridge.chat("Saved enough Earthquake PP for safe strats on Giovanni!")
					elseif earthquakePP >= 3 and battle.pp("horn_drill") >= 5 and (yolo or pokemon.info("nidoking", "hp") >= ryhornDamage) then -- RISK
						bridge.chat("Using risky strats on Giovanni to skip the extra Max Ether...")
					else
						riskGiovanni = false
					end
				end
				return true
			end
			local message = "Ran out of Earthquake PP :( "
			if yolo then
				message = message.."Risking on Giovanni."
			else
				message = message.."Time for standard strats."
			end
			bridge.chat(message)
			riskGiovanni = false
		end
		return strategyFunctions.potion({hp=50, yolo=ryhornDamage})
	end,

	fightGiovanni = function()
		if battle.isActive() then
			if initialize() then
				tempDir = battle.pp("earthquake")
				canProgress = true
			end
			local forced, needsXSpecial
			local startEqPP = tempDir
			if riskGiovanni then
				if startEqPP < 5 then
					needsXSpecial = true
				end
				if needsXSpecial or battle.pp("earthquake") < 4 then
					forced = "ice_beam"
				end
			else
				needsXSpecial = startEqPP < 2
				if pokemon.isOpponent("rhydon") then
					forced = "ice_beam"
				end
			end
			if needsXSpecial and not prepare("x_special") then
				return false
			end
			battle.automate(forced)
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

-- 15: GIOVANNI

	viridianRival = function()
		if battle.isActive() then
			if not canProgress then
				if riskGiovanni or nidoSpecial < 45 or pokemon.index(0, "speed") < 134 then
					tempDir = "x_special"
				else
					print("Skip X Special strats!")
				end
				canProgress = true
			end
			if prepare("x_accuracy", tempDir) then
				local forced
				if pokemon.isOpponent("pidgeot") then
					forced = "thunderbolt"
				elseif riskGiovanni then
					if pokemon.isOpponent("rhyhorn") or opponentDamaged() then
						forced = "ice_beam"
					elseif pokemon.isOpponent("gyarados") then
						forced = "thunderbolt"
					elseif pokemon.isOpponent("growlithe", "alakazam") then
						forced = "earthquake"
					end
				end
				battle.automate(forced)
			end
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	ether = function(data)
		local main = memory.value("menu", "main")
		data.item = tempDir
		if tempDir and completedMenuFor(data) then
			if closeMenuFor(data) then
				return true
			end
		else
			if not tempDir then
				if data.max then
					-- TODO don't skip center if not in redbar
					maxEtherSkip = nidoAttack > 53 and battle.pp("earthquake") > 0 and battle.pp("horn_drill") > 3
					if maxEtherSkip then
						return true
					end
					bridge.chat("Grabbing the Max Ether to skip the Elite 4 Center")
				end
				tempDir = inventory.contains("ether", "max_ether")
				if not tempDir then
					return true
				end
				tries = inventory.count(tempDir) --TODO remove?
			end
			if memory.value("menu", "main") == 144 and menu.getCol() == 5 then
				if memory.value("battle", "menu") ~= 95 then
					menu.select(pokemon.battleMove("horn_drill"), true)
				else
					input.cancel()
				end
			elseif menu.pause() then
				inventory.use(tempDir, "nidoking")
			end
		end
	end,

	pickMaxEther = function()
		if not canProgress then
			if maxEtherSkip then
				return true
			end
			if memory.value("player", "moving") == 0 then
				if player.isFacing("Right") then
					canProgress = true
				end
				tries = not tries
				if tries then
					input.press("Right", 1)
				end
			end
			return false
		end
		if inventory.contains("max_ether") then
			return true
		end
		player.interact("Right")
	end,

	push = function(data)
		local pos
		if data.dir == "Up" or data.dir == "Down" then
			pos = data.y
		else
			pos = data.x
		end
		local newP = memory.raw(pos)
		if tries == 0 then
			tries = {start=newP}
		elseif tries.start ~= newP then
			return true
		end
		input.press(data.dir, 0)
	end,

	healBeforeLorelei = function()
		if initialize() then
			local canPotion
			if inventory.contains("potion") and hasHealthFor("LoreleiDewgong", 20) then
				canPotion = true
			elseif inventory.contains("super_potion") and hasHealthFor("LoreleiDewgong", 50) then
				canPotion = true
			end
			if not canPotion then
				return true
			end
			bridge.chat("Healing before Lorelei to skip the Elite 4 Center...")
		end
		return strategyFunctions.potion({hp=combat.healthFor("LoreleiDewgong")})
	end,

	depositPokemon = function()
		local toSize
		if hasHealthFor("LoreleiDewgong") then
			toSize = 1
		else
			toSize = 2
		end
		if memory.value("player", "party_size") == toSize then
			if menu.close() then
				return true
			end
		else
			if not textbox.isActive() then
				player.interact("Up")
			else
				local pc = memory.value("menu", "size")
				if memory.value("battle", "menu") ~= 95 and (pc == 2 or pc == 4) then
					if menu.getCol() == 10 then
						input.press("A")
					else
						menu.select(1)
					end
				else
					input.press("A")
				end
			end
		end
	end,

	centerSkip = function()
		setYolo("e4center")
		local message = "Skipping the Center and attempting to redbar "
		if hasHealthFor("LoreleiDewgong") then
			message = message.."off Lorelei..."
		else
			message = message.."the Elite 4!"
		end
		bridge.chat(message)
		return true
	end,

	lorelei = function()
		if battle.isActive() then
			canProgress = true
			if battle.redeployNidoking() then
				return false
			end
			if pokemon.isOpponent("dewgong") then
				if battle.sacrifice("pidgey", "spearow", "squirtle", "paras", "oddish") then
					return false
				end
			end
			if prepare("x_accuracy") then
				battle.automate()
			end
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

-- 16: LORELEI

	bruno = function()
		if battle.isActive() then
			canProgress = true
			local forced
			if pokemon.isOpponent("onix") then
				forced = "ice_beam"
				-- local curr_hp, red_hp = pokemon.info("nidoking", "hp"), redHP()
				-- if curr_hp > red_hp then
				-- 	local enemyMove, enemyTurns = combat.enemyAttack()
				-- 	if enemyTurns and enemyTurns > 1 then
				-- 		local rockDmg = enemyMove.damage
				-- 		if curr_hp - rockDmg <= red_hp then
				-- 			forced = "thunderbolt"
				-- 		end
				-- 	end
				-- end
			end
			if prepare("x_accuracy") then
				battle.automate(forced)
			end
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	agatha = function() --TODO test without x acc
		if battle.isActive() then
			canProgress = true
			if combat.isSleeping() then
				inventory.use("pokeflute", nil, true)
				return false
			end
			if pokemon.isOpponent("gengar") then
				local currentHP = pokemon.info("nidoking", "hp")
				-- if not yolo and currentHP <= 56 and not isPrepared("x_speed") then
				if not yolo and currentHP <= 56 and not isPrepared("x_accuracy", "x_speed") then
					local toPotion = inventory.contains("full_restore", "super_potion")
					if toPotion then
						inventory.use(toPotion, nil, true)
						return false
					end
				end
				-- if not prepare("x_speed") then
				if not prepare("x_accuracy", "x_speed") then
					return false
				end
			end
			battle.automate()
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	prepareForLance = function()
		local enableFull
		if hasHealthFor("LanceGyarados", 100) then
			enableFull = inventory.count("super_potion") < 2
		elseif hasHealthFor("LanceGyarados", 50) then
			enableFull = not inventory.contains("super_potion")
		else
			enableFull = true
		end
		local min_recovery = combat.healthFor("LanceGyarados")
		return strategyFunctions.potion({hp=min_recovery, full=enableFull, chain=true})
	end,

	lance = function()
		local xItem
		if pokemon.isOpponent("dragonair") then
			xItem = "x_speed"
		else
			xItem = "x_special"
		end
		return prepare(xItem)
	end,

	prepareForBlue = function()
		if initialize() then
			setYolo("blue")
		end
		local skyDmg = combat.healthFor("BlueSky") * 0.9
		local wingDmg = combat.healthFor("BluePidgeot")
		return strategyFunctions.potion({hp=skyDmg-50, yolo=wingDmg, full=true})
	end,

	blue = function()
		if battle.isActive() then
			if not canProgress then
				canProgress = true
				if nidoSpecial >= 45 and pokemon.index(0, "speed") >= 52 and inventory.contains("x_special") then
					tempDir = "x_special"
				else
					tempDir = "x_speed"
				end
				if not STREAMING_MODE then
					tempDir = "x_speed"
				end
			end

			local boostFirst = pokemon.index(0, "hp") < 55
			local firstItem, secondItem
			if boostFirst then
				firstItem = tempDir
				secondItem = "x_accuracy"
			else
				firstItem = "x_accuracy"
				secondItem = tempDir
			end

			local forced = "horn_drill"

			if memory.value("battle", "turns") > 0 then
				local skyDamage = combat.healthFor("BlueSky")
				local healCutoff = skyDamage * 0.825
				if initialize() then
					if not isPrepared("x_accuracy", tempDir) then
						local msg = "Uh oh... First-turn Sky Attack could end the run here, "
						if pokemon.index(0, "hp") > skyDamage then
							msg = msg.."no criticals pls D:"
						elseif canHealFor(healCutoff) then
							msg = msg.."attempting to heal for it"
							if not canHealFor(skyDamage) then
								msg = msg.." (damage range)"
							end
							msg = msg.."."
						else
							msg = msg.."and nothing left to heal with BibleThump"
						end
						bridge.chat(msg)
					end
				end

				if prepare(firstItem) then
					if not isPrepared(secondItem) then
						local toPotion = canHealFor(healCutoff)
						if toPotion then
							inventory.use(toPotion, nil, true)
							return false
						end
					end
					if prepare("x_accuracy", tempDir) then
						battle.automate(forced)
					end
				end
			else
				if prepare(firstItem, secondItem) then
					if pokemon.isOpponent("alakazam") then
						if tempDir == "x_speed" then
							forced = "earthquake"
						end
					elseif pokemon.isOpponent("rhydon") then
						if tempDir == "x_special" then
							forced = "ice_beam"
						end
					end
					battle.automate(forced)
				end
			end
		elseif canProgress then
			return true
		else
			textbox.handle()
		end
	end,

	champion = function()
		if canProgress then
			if tries > 1500 then
				return hardReset("Beat the game in "..canProgress.." !")
			end
			if tries == 0 then
				bridge.tweet("Beat Pokemon Red in "..canProgress.."!")
				if strategies.seed then
					print(utils.frames().." frames, with seed "..strategies.seed)
					print("Please save this seed number to share, if you would like proof of your run!")
				end
			end
			tries = tries + 1
		elseif memory.value("menu", "shop_current") == 252 then
			strategyFunctions.split({finished=true})
			canProgress = utils.elapsedTime()
		else
			input.cancel()
		end
	end
}

function strategies.execute(data)
	if strategyFunctions[data.s](data) then
		tries = 0
		canProgress = false
		initialized = false
		tempDir = nil
		if resetting then
			return nil
		end
		return true
	end
	return false
end

function strategies.init(midGame)
	if not STREAMING_MODE then
		-- setYolo(0)
		nidoAttack = 55
		nidoSpeed = 50
		nidoSpecial = 45
		riskGiovanni = true
		splitTime = utils.timeSince(0)
		print(nidoAttack.." x "..nidoSpeed.." "..nidoSpecial)
	end
	if midGame then
		combat.factorPP(true)
	end
end

function strategies.softReset()
	canProgress = false
	initialized = false
	maxEtherSkip = false
	tempDir = nil
	strategies.moonEncounters = nil
	tries = 0
	splitNumber, splitTime = 0, 0
	deepRun = false
	resetting = nil
	yolo = false
end

return strategies
