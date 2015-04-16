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
local Shop = require "action.shop"
local Utils = require "util.utils"

local Inventory = require "storage.inventory"
local Pokemon = require "storage.pokemon"

local yellow = YELLOW
local splitNumber, splitTime = 0, 0
local resetting

local status = {tries = 0, canProgress = nil, initialized = false}
local stats = {}
Strategies.status = status
Strategies.stats = stats
Strategies.updates = {}
Strategies.deepRun = false

local strategyFunctions

-- RISK/RESET

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
	else
		client.reboot_core()
	end
	return true
end

function Strategies.reset(reason, extra, wait)
	local time = Utils.elapsedTime()
	local resetMessage = "reset"
	if time then
		resetMessage = resetMessage.." after "..time
	end
	resetMessage = resetMessage.." at "..Control.areaName
	local separator
	if Strategies.deepRun and not Control.yolo then
		separator = " BibleThump"
	else
		separator = ":"
	end
	resetMessage = resetMessage..separator.." "..reason
	if status.tweeted then
		Strategies.tweetProgress(resetMessage)
	end
	return Strategies.hardReset(resetMessage, extra, wait)
end

function Strategies.death(extra)
	local reason
	if Control.missed then
		reason = "Missed"
	elseif Control.criticaled then
		reason = "Critical'd"
	elseif Control.yolo then
		reason = "Yolo strats"
	else
		reason = "Died"
	end
	return Strategies.reset(reason, extra)
end

function Strategies.overMinute(min)
	if type(min) == "string" then
		min = Strategies.getTimeRequirement(min)
	end
	return Utils.igt() > (min * 60)
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

function Strategies.tweetProgress(message, progress)
	if progress then
		Strategies.updates[progress] = true
		message = message.." http://www.twitch.tv/thepokebot"
	end
	Bridge.tweet(message)
end

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
	local afterHealth = math.min(Pokemon.index(0, "hp") + extra, Pokemon.index(0, "max_hp"))
	return afterHealth > Combat.healthFor(opponent)
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

local function interact(direction, extended)
	if Battle.handleWild() then
		if Battle.isActive() then
			return true
		end
		if Textbox.isActive() then
			if status.interacted then
				return true
			end
			Input.cancel()
		else
			if Player.interact(direction, extended) then
				status.interacted = true
			end
		end
	end
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

local function dodgeSideways(options)
	local left = 1
	if options.left then
		left = -1
	end
	local px, py = Player.position()
	if px * left > (options.sx + (options.dist or 1)) * left then
		return true
	end
	local wx, wy = px, py
	if px * left > options.sx * left then
		wx = px + 1 * left
	elseif py == options.sy or py == options.dodge then
		if px + left == options.npcX and py - Memory.raw(options.npc) == options.offset then
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
	if count == 0 or (status.startCount and count + (data.amount or 1) <= status.startCount) then
		return true
	end
	return false
end

function Strategies.closeMenuFor(data)
	if (not status.menuOpened and not data.close) or data.chain then
		return true
	end
	return Menu.close()
end

function Strategies.useItem(data)
	local main = Memory.value("menu", "main")
	if not status.startCount then
		status.startCount = Inventory.count(data.item)
		if status.startCount == 0 then
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
	elseif Menu.pause() then
		status.menuOpened = true
		Inventory.use(data.item, data.poke)
	end
end

function Strategies.tossItem(...)
	if not status.startCount then
		status.startCount = Inventory.count()
	elseif Inventory.count() < status.startCount then
		return true
	end
	local tossItem = Inventory.contains(...)
	if tossItem ~= status.toss then
		status.toss = tossItem
		p("Tossing "..tossItem.." to make space", Inventory.count())
	end
	if not Inventory.useItemOption(tossItem, nil, 1) then
		if Menu.pause() then
			Input.press("A")
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
	elseif status.tries > 0 and not Menu.isOpened() then
		return true
	end
	return false
end

function Strategies.isPrepared(...)
	if not status.preparing then
		return false
	end
	for i,name in ipairs(arg) do
		local currentCount = Inventory.count(name)
		if currentCount > 0 then
			local previousCount = status.preparing[name]
			if previousCount == nil or currentCount == previousCount then
				return false
			end
		end
	end
	return true
end

function Strategies.prepare(...)
	if not status.preparing then
		status.preparing = {}
	end
	local item
	for idx,name in ipairs(arg) do
		local currentCount = Inventory.count(name)
		local needsItem = currentCount > 0
		local previousCount = status.preparing[name]
		if previousCount == nil then
			status.preparing[name] = currentCount
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

local function nidokingStats()
	local att = Pokemon.index(0, "attack")
	local def = Pokemon.index(0, "defense")
	local spd = Pokemon.index(0, "speed")
	local scl = Pokemon.index(0, "special")
	local statDesc = att.." "..def.." "..spd.." "..scl
	local attDv, defDV, spdDv, sclDV = Pokemon.getDVs("nidoking")
	stats.nidoran = {
		attack = att,
		defense = def,
		speed = spd,
		special = scl,
		level4 = stats.nidoran.level4,
		rating = stats.nidoran.rating,
		attackDV = attDv,
		defenseDV = defDV,
		speedDV = spdDv,
		specialDV = sclDV,
	}

	p(attDv, defDV, spdDv, sclDV)
	print(statDesc)
	Bridge.stats(statDesc)
end

function Strategies.completeCans()
	local px, py = Player.position()
	if px == 4 and py == 6 then
		status.tries = status.tries + 1
		local timeLimit = Strategies.getTimeRequirement("trash") + 1.5
		if Strategies.resetTime(timeLimit, "complete Trashcans ("..status.tries.." tries)") then
			return true
		end
		Strategies.setYolo("trash")

		local prefix
		local suffix = "!"
		if status.tries <= 1 then
			prefix = "PERFECT"
		elseif status.tries <= (yellow and 2 or 3) then
			prefix = "Amazing"
		elseif status.tries <= (yellow and 4 or 6) then
			prefix = "Great"
		elseif status.tries <= (yellow and 6 or 9) then
			prefix = "Good"
		elseif status.tries <= (yellow and 10 or 22) then
			prefix = "Ugh"
			suffix = ""
		else -- TODO trashcans WR
			prefix = "Reset me now"
			suffix = " BibleThump"
		end
		Bridge.chat(" "..prefix..", "..status.tries.." try Trashcans"..suffix, Utils.elapsedTime())
		return true
	end
	local completePath = {
		Down = {{2,11}, {8,7}},
		Right = {{2,12}, {3,12}, {1,6}, {2,6}, {3,6}},
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
	Input.press(walkIn, 0)
end

-- GENERALIZED STRATEGIES

Strategies.functions = {

	tweetVictoryRoad = function()
		local elt = Utils.elapsedTime()
		local pbn = ""
		if not Strategies.overMinute("victory_road") then
			pbn = " (PB pace)"
		end
		local elt = Utils.elapsedTime()
		Strategies.tweetProgress("Entering Victory Road at "..elt..pbn.." on our way to the Elite Four", "victory")
		return true
	end,

	bicycle = function()
		if Memory.value("player", "bicycle") == 1 then
			if Menu.close() then
				return true
			end
		else
			return Strategies.useItem({item="bicycle"})
		end
	end,

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
		if Strategies.replay then
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
		return interact(data.dir, false)
	end,

	talk = function(data)
		return interact(data.dir, data.long)
	end,

	take = function(data)
		return interact(data.dir, false)
	end,

	confirm = function(data)
		if Battle.handleWild() then
			if Textbox.isActive() then
				status.talked = true
				Input.cancel(data.type or "A")
			else
				if status.talked then
					return true
				end
				Player.interact(data.dir, false)
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
			if not status.checked and data.item ~= "carbos" and not Inventory.contains(data.item) then
				print("No "..data.item.." available!")
			end
			status.checked = true
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
		toHP = math.min(toHP, Pokemon.index(0, "max_hp"))
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
					status.menuOpened = true
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
				Input.press("B")
			elseif Menu.close() then
				return true
			end
		else
			if not status.triedTeaching then
				status.triedTeaching = true
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
				status.menuOpened = true
			else
				Menu.pause()
			end
		end
	end,

	skill = function(data)
		if completedSkillFor(data) then
			if yellow then
				if not Menu.hasTextbox() then
					return true
				end
			else
				if not Menu.isOpened() then
					return true
				end
			end
			Input.press("B")
		elseif not data.dir or Player.face(data.dir) then
			if Pokemon.use(data.move) then
				status.tries = status.tries + 1
			elseif yellow and Menu.hasTextbox() then
				if Textbox.handle() then
					return true
				end
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
			saffron = {72, "Down"},
		}

		local main = Memory.value("menu", "main")
		if main == (yellow and 144 or 228) then
			local currentCity = Memory.value("game", "fly")
			local destination = cities[data.dest]
			local press
			if destination[1] - currentCity == 0 then
				press = "A"
			else
				press = destination[2]
			end
			Input.press(press)
		elseif not Pokemon.use("fly") then
			Menu.pause()
		end
	end,

	swap = function(data)
		local itemIndex = data.item
		if type(itemIndex) == "string" then
			itemIndex = Inventory.indexOf(itemIndex)
		end
		local destIndex = data.dest
		if type(destIndex) == "string" then
			destIndex = Inventory.indexOf(destIndex)
		end
		local swapComplete
		if itemIndex < 0 or destIndex < 0 then
			swapComplete = true
			if not status.swapUnavailable then
				status.swapUnavailable = true
				p("Not available to swap", data.item, data.dest, itemIndex, destIndex)
			end
		else
			swapComplete = itemIndex == destIndex
		end

		if swapComplete then
			if Strategies.closeMenuFor(data) then
				return true
			end
		else
			local main = Memory.value("menu", "main")
			if main == 128 then
				if Menu.getCol() ~= 5 then
					Menu.select(2, true)
				else
					local selection = Memory.value("menu", "selection_mode")
					if selection == 0 then
						if Menu.select(destIndex, "accelerate", true, nil, true) then
							Input.press("Select")
						end
					else
						if Menu.select(itemIndex, "accelerate", true, nil, true) then
							Input.press("Select")
						end
					end
				end
			else
				Menu.pause()
			end
		end
	end,

	swapMove = function(data)
		return Battle.swapMove(data.move, data.to)
	end,

	wait = function()
		print("Please save state")
		Input.press("Start", 999999999)
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
		if Menu.pause() then
			return true
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
				Player.interact(data.dir, false)
			else
				Input.cancel()
			end
		end
	end,

	waitToPauseFromBattle = function()
		local main = Memory.value("menu", "main")
		if main == 128 then
			if status.canProgress then
				return true
			end
		elseif Battle.isActive() then
			status.canProgress = false
			Battle.automate()
		elseif main == (yellow and 23 or 123) then
			status.canProgress = true
			Input.press("B")
		elseif Textbox.handle() then
			Input.press("Start", 2)
		end
	end,

	waitToReceive = function()
		local main = Memory.value("menu", "main")
		if main == 128 then
			if status.canProgress then
				return true
			end
		elseif main == 32 or main == 123 then
			status.canProgress = true
			Input.cancel()
		else
			Input.press("Start", 2)
		end
	end,

	allowDeath = function(data)
		Control.canDie(data.on)
		return true
	end,

	leer = function(data)
		local bm = Combat.bestMove()
		if not bm or bm.minTurns < 3 then
			if Battle.isActive() then
				status.canProgress = true
			elseif status.canProgress then
				return true
			end
			Battle.automate()
			return false
		end
		local opp = Battle.opponent()
		local defLimit = 9001
		for i,poke in ipairs(data) do
			if opp == poke[1] then
				local minimumAttack = poke[3]
				if not minimumAttack or stats.nidoran.attack > minimumAttack then
					defLimit = poke[2]
				end
				break
			end
		end
		return Strategies.buffTo("leer", defLimit)
	end,

	fightX = function(data)
		return Strategies.prepare("x_"..data.x)
	end,

	-- ROUTE

	swapNidoran = function()
		local main = Memory.value("menu", "main")
		local nidoranIndex = Pokemon.indexOf("nidoran")
		if nidoranIndex == 0 then
			if Menu.close() then
				return true
			end
		elseif Menu.pause() then
			if yellow then
				if Inventory.contains("potion") and Pokemon.info("nidoran", "hp") < 15 then
					Inventory.use("potion", "nidoran")
					return false
				end
			else
				if Pokemon.info("squirtle", "status") > 0 then
					Inventory.use("antidote", "squirtle")
					return false
				end
				if Inventory.contains("potion") and Pokemon.info("squirtle", "hp") < 15 then
					Inventory.use("potion", "squirtle")
					return false
				end
			end

			local column = Menu.getCol()
			if main == 128 then
				if column == 11 then
					Menu.select(1, true)
				elseif column == 12 then
					Menu.select(1, true)
				else
					Input.press("B")
				end
			elseif main == Menu.pokemon then --TODO check loop
				if Memory.value("menu", "selection_mode") == 1 then
					Menu.select(nidoranIndex, true)
				else
					Menu.select(0, true)
				end
			else
				Input.press("B")
			end
		end
	end,

	dodgePalletBoy = function()
		return Strategies.dodgeUp(0x0223, 14, 14, 15, 7)
	end,

	evolveNidorino = function()
		if Pokemon.inParty("nidorino") then
			Bridge.caught("nidorino")
			return true
		end
		if Battle.isActive() then
			status.tries = 0
			status.canProgress = true
			if not Battle.opponentAlive() then
				Input.press("A")
			else
				Battle.automate()
			end
		elseif status.tries > 3600 then
			print("Broke from Nidorino on tries")
			return true
		else
			if status.canProgress then
				status.tries = status.tries + 1
			end
			Input.press("A")
		end
	end,

	catchFlierBackup = function()
		if Strategies.initialize() then
			Control.canDie(true)
		end
		if not Control.canCatch() then
			return true
		end
		local caught = Pokemon.inParty("pidgey", "spearow")
		if Battle.isActive() then
			if Memory.double("battle", "our_hp") == 0 then
				if Pokemon.info("squirtle", "hp") == 0 then
					Control.canDie(false)
				elseif Menu.onPokemonSelect() then
					Pokemon.select("squirtle")
				else
					Input.press("A")
				end
			else
				Battle.handle()
			end
		else
			local birdPath
			local px, py = Player.position()
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
				Walk.step(px, py)
			else
				birdPath = {{32,10}, {32,11}, {34,11}, {34,10}, {37,10}}
			end
			if birdPath then
				Walk.custom(birdPath)
			end
		end
	end,

	evolveNidoking = function(data)
		if Battle.handleWild() then
			local usedMoonStone = not Inventory.contains("moon_stone")
			if Strategies.initialize() then
				if usedMoonStone then
					return true
				end
				if data.early then
					if not Control.getMoonExp then
						return true
					end
					if data.poke then
						if stats.nidoran.attack > 15 or not Pokemon.inParty(data.poke) then
							return true
						end
					end
					if data.exp and Pokemon.getExp() > data.exp then
						return true
					end
				end
			end
			if usedMoonStone then
				if not status.canProgress then
					Bridge.caught("nidoking")
					status.canProgress = true
				end
				if Menu.close() then
					return true
				end
			elseif not Inventory.use("moon_stone") then
				Menu.pause()
			end
		end
	end,

	helix = function()
		if Battle.handleWild() then
			if Inventory.contains("helix_fossil") then
				return true
			end
			Player.interact("Up", false)
		end
	end,

	reportMtMoon = function()
		if Battle.pp("horn_attack") == 0 then
			print("ERR: Ran out of Horn Attacks")
		end
		if Control.moonEncounters then
			local catchPokemon = yellow and "sandshrew" or "paras"
			local capsName = Utils.capitalize(catchPokemon)
			local parasStatus
			local conjunction = "but"
			local goodEncounters = Control.moonEncounters < 10
			local catchDescription
			if Pokemon.inParty(catchPokemon) then
				catchDescription = catchPokemon
				if goodEncounters then
					conjunction = "and"
				end
				parasStatus = "we caught a "..capsName.."!"
			else
				catchDescription = "no_"..catchPokemon
				if not goodEncounters then
					conjunction = "and"
				end
				parasStatus = "we didn't catch a "..capsName.." :("
			end
			Bridge.caught(catchDescription)
			Bridge.chat(Control.moonEncounters.." Moon encounters, "..conjunction.." "..parasStatus)
			Control.moonEncounters = nil
		end

		Strategies.resetTime("mt_moon", "complete Mt. Moon", true)
		return true
	end,

	dodgeCerulean = function(data)
		local left = data.left
		return dodgeSideways {
			npc = 0x0242,
			npcX = 15,
			sx = (left and 16 or 14), sy = 18,
			dodge = (left and 17 or 19),
			offset = 10,
			dist = (left and -7 or 4),
			left = left
		}
	end,

	rareCandyEarly = function(data)
		if Strategies.initialize() then
			if Pokemon.info("nidoking", "level") ~= 20 then
				return true
			end
			if yellow then
				p("RCE", Pokemon.getExp())
				if Pokemon.getExp() > 5500 then --TODO
					return true
				end
			else
				if Pokemon.getExp() > 5550 then
					return true
				end
			end
		end
		return strategyFunctions.item({item="rare_candy", amount=2, poke="nidoking", chain=data.chain, close=data.close})
	end,

	teachThrash = function()
		if Strategies.initialize() then
			if Pokemon.hasMove("thrash") or Pokemon.info("nidoking", "level") < 21 or not Inventory.contains("rare_candy") then
				return true
			end
		end
		local replacementMove = yellow and "tackle" or "leer"
		if strategyFunctions.teach({move="thrash",item="rare_candy",replace=replacementMove}) then
			if Menu.close() then
				nidokingStats()
				return true
			end
		end
	end,

	learnThrash = function()
		if Battle.isActive() then
			status.canProgress = true
			local settingsRow = Memory.value("menu", "settings_row")
			if settingsRow == 8 then
				local column = Memory.value("menu", "column")
				if column == 15 then
					Input.press("A")
				elseif column == 5 then
					local replacementMove = yellow and "tackle" or "leer"
					local replaceIndex = Pokemon.moveIndex(replacementMove, "nidoking")
					if replaceIndex then
						Menu.select(replaceIndex - 1, true)
						status.learned = true
					else
						Input.cancel()
					end
				end
			else
				Battle.automate()
			end
		elseif status.canProgress then
			if status.learned then
				print("learn'd")
				nidokingStats()
			end
			return true
		end
	end,

	swapThrash = function()
		if not Battle.isActive() then
			if Textbox.handle() and status.canProgress then
				return true
			end
		else
			status.canProgress = true
			return Battle.swapMove("thrash", 0)
		end
	end,

	jingleSkip = function()
		if status.canProgress then
			local px, py = Player.position()
			if px < 4 then
				return true
			end
			Input.press("Left", 0)
		else
			Input.press("A", 0)
			status.canProgress = true
		end
	end,

	announceFourTurn = function()
		Bridge.chat("needs a 4-turn thrash (1 in 2 chance) to beat this dangerous trainer...")
		return true
	end,

	redbarCubone = function()
		if Battle.isActive() then
			local forced
			status.canProgress = true
			if Pokemon.isOpponent("cubone") then
				local enemyMove, enemyTurns = Combat.enemyAttack()
				if enemyTurns then
					local curr_hp, red_hp = Combat.hp(), Combat.redHP()
					local clubDmg = enemyMove.damage
					local afterHit = curr_hp - clubDmg
					local acceptableHealth = Control.yolo and -1 or 1
					if afterHit >= acceptableHealth and afterHit < red_hp - 2 then
						forced = "thunderbolt"
					else
						afterHit = afterHit - clubDmg
						if afterHit > 1 and afterHit < red_hp - 4 then
							forced = "thunderbolt"
						end
					end
					if forced and Strategies.initialize() then
						Bridge.chat("is using Thunderbolt to attempt to redbar off Cubone")
					end
				end
				Control.ignoreMiss = forced ~= nil
			end
			Battle.automate(forced)
		elseif status.canProgress then
			return true
		else
			Battle.automate()
		end
	end,

	announceOddish = function()
		if Pokemon.info("nidoking", "level") < 30 then
			Bridge.chat("needs a good damage range to 1-shot this Oddish, which can Paralyze")
		end
		return true
	end,

	shopTM07 = function()
		return Shop.transaction {
			direction = "Up",
			buy = {{name="horn_drill", index=3}}
		}
	end,

	shopRepels = function()
		local repelCount = yellow and 10 or 9
		return Shop.transaction {
			direction = "Up",
			buy = {{name="super_repel", index=3, amount=repelCount}}
		}
	end,

	shopPokeDoll = function()
		return Shop.transaction {
			direction = "Down",
			buy = {{name="pokedoll", index=0}}
		}
	end,

	shopVending = function()
		return Shop.vend {
			direction = "Up",
			buy = {{name="fresh_water", index=0}, {name="soda_pop", index=1}}
		}
	end,

	giveWater = function()
		if not Inventory.contains("fresh_water", "soda_pop") then
			return true
		end
		if Textbox.isActive() then
			Input.cancel("A")
		else
			local cx, cy = Memory.raw(0x0223) - 3, Memory.raw(0x0222) - 3
			local px, py = Player.position()
			if Utils.dist(cx, cy, px, py) == 1 then
				Player.interact(Walk.dir(px, py, cx, cy))
			else
				Walk.step(cx, cy)
			end
		end
	end,

	shopExtraWater = function()
		return Shop.vend {
			direction = "Up",
			buy = {{name="fresh_water", index=0}}
		}
	end,

	digFight = function()
		if Strategies.initialize() then
			if Combat.inRedBar() then
				Bridge.chat("is using Rock Slide to one-hit these Ghastlies in red-bar (each is 1 in 10 to miss)")
			end
		end
		if Battle.isActive() then
			status.canProgress = true
			local currentlyDead = Memory.double("battle", "our_hp") == 0
			if currentlyDead then
				if not status.died then
					status.died = true
					Bridge.chat(" Rock Slide missed BibleThump Trying to finish them off with Dig...")
				end
				local backupPokemon = Pokemon.getSacrifice("paras", "squirtle", "sandshrew", "charmander")
				if not backupPokemon then
					return Strategies.death()
				end
				if Menu.onPokemonSelect() then
					Pokemon.select(backupPokemon)
				else
					Input.press("A")
				end
			else
				Battle.automate()
			end
		elseif status.canProgress then
			return true
		else
			Textbox.handle()
		end
	end,

	pokeDoll = function()
		if Battle.isActive() then
			status.canProgress = true
			-- {s="swap",item="potion",dest="x_special",chain=true}, --TODO yellow
			Inventory.use("pokedoll", nil, true)
		elseif status.canProgress then
			return true
		else
			Input.cancel()
		end
	end,

	silphElevator = function()
		if Menu.isOpened() then
			status.canProgress = true
			Menu.select(9, false, true)
		else
			if status.canProgress then
				return true
			end
			Player.interact("Up")
		end
	end,

	playPokeFlute = function()
		if Battle.isActive() then
			return true
		end
		if Menu.hasTextbox() then
			Input.cancel()
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
		if not status.startPosition then
			status.startPosition = newP
		elseif status.startPosition ~= newP then
			return true
		end
		Input.press(data.dir, 0)
	end,

	drivebyRareCandy = function()
		if Textbox.isActive() then
			status.canProgress = true
			Input.cancel()
		elseif status.canProgress then
			return true
		else
			local px, py = Player.position()
			if py < 13 then
				status.tries = 0
				return
			end
			if py == 13 and status.tries % 2 == 0 then
				Input.press("A", 2)
			else
				Input.press("Up")
				status.tries = 0
			end
			status.tries = status.tries + 1
		end
	end,

	safariCarbos = function()
		if Strategies.initialize() then
			Strategies.setYolo("safari_carbos")
			status.carbos = Inventory.count("carbos")
		end
		local minDV = yellow and 9 or 7
		if stats.nidoran.speedDV >= minDV then
			return true
		end
		if Inventory.count("carbos") ~= status.carbos then
			if Walk.step(20, 20) then
				return true
			end
		else
			local px, py = Player.position()
			if px < 21 then
				Walk.step(21, py)
			elseif px == 21 and py == 13 then
				Player.interact("Left")
			else
				Walk.step(21, 13)
			end
		end
	end,

	centerSkipFullRestore = function()
		if Strategies.initialize() then
			if Control.yolo or Inventory.contains("full_restore") then
				return true
			end
			Bridge.chat("needs to grab the backup Full Restore here")
		end
		local px, py = Player.position()
		if px < 21 then
			px = 21
		elseif py < 9 then
			py = 9
		else
			return strategyFunctions.interact({dir="Down"})
		end
		Walk.step(px, py)
	end,

	dodgeGirl = function()
		local gx, gy = Memory.raw(0x0223) - 5, Memory.raw(0x0222)
		local px, py = Player.position()
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
		Walk.step(px, py)
	end,

	cinnabarCarbos = function()
		local px, py = Player.position()
		if px == 21 then
			return true
		end
		if Strategies.initialize() then
			status.startCount = Inventory.count("carbos")
		end
		local minDV = yellow and 11 or 10
		if stats.nidoran.speedDV >= minDV then
			px, py = 21, 20
		else
			if py == 20 then
				py = 21
			elseif px == 17 and Inventory.count("carbos") == status.startCount then
				Player.interact("Right")
				return false
			else
				px = 21
			end
		end
		Walk.step(px, py)
	end,

	checkEther = function()
		-- TODO don't skip center if not in redbar
		Strategies.maxEtherSkip = not Strategies.requiresE4Center()
		if not Strategies.maxEtherSkip then
			Bridge.chat("is grabbing the Max Ether to skip the Elite 4 Center")
		end
		return true
	end,

	ether = function(data)
		local main = Memory.value("menu", "main")
		data.item = status.item
		if status.item and Strategies.completedMenuFor(data) then
			if Strategies.closeMenuFor(data) then
				return true
			end
		else
			if not status.item then
				if data.max and Strategies.maxEtherSkip then
					return true
				end
				status.item = Inventory.contains("ether", "max_ether", "elixer")
				if not status.item then
					if Strategies.closeMenuFor(data) then
						return true
					end
					print("No Ether - "..Control.areaName)
					return false
				end
			end
			if status.item == "elixer" then
				return Strategies.useItem({item="elixer", poke="nidoking", chain=data.chain, close=data.close})
			end
			if Memory.value("menu", "main") == 144 and Menu.getCol() == 5 then
				if Menu.hasTextbox() then
					Input.cancel()
				else
					Menu.select(Pokemon.battleMove("horn_drill"), true)
				end
			elseif Menu.pause() then
				Inventory.use(status.item, "nidoking")
				status.menuOpened = true
			end
		end
	end,

	tossInVictoryRoad = function()
		if Strategies.initialize() then
			if Strategies.maxEtherSkip then
				return true
			end
			if Inventory.count("ether") + Inventory.count("elixer") >= 2 then
				return true
			end
		end
		return Strategies.tossItem("antidote", "pokeball")
	end,

	grabMaxEther = function()
		if Strategies.initialize() then
			if Strategies.maxEtherSkip and (Inventory.count("ether") + Inventory.count("elixer") >= 2) then
				return true
			end
			if Inventory.isFull() then
				return true
			end
		end
		if Inventory.contains("max_ether") then
			return true
		end
		local px, py = Player.position()
		if px > 7 then
			return Strategies.reset("Accidentally walked on the island :(", px, true)
		end
		if Memory.value("player", "moving") == 0 then
			Player.interact("Right")
		end
	end,

	prepareForLance = function()
		local enableFull
		if Strategies.hasHealthFor("LanceGyarados", 100) then
			enableFull = Inventory.count("super_potion") < 2
		elseif Strategies.hasHealthFor("LanceGyarados", 50) then
			enableFull = not Inventory.contains("super_potion")
		else
			enableFull = true
		end
		local min_recovery = Combat.healthFor("LanceGyarados")
		if not Control.yolo then
			min_recovery = min_recovery + 2
		end
		return strategyFunctions.potion({hp=min_recovery, full=enableFull, chain=true})
	end,

	champion = function()
		if status.finishTime then
			if not status.frames then
				status.frames = 0
				local victoryMessage = "Beat Pokemon "..Utils.capitalize(GAME_NAME).." in "..status.finishTime
				if not Strategies.overMinute("champion") then
					victoryMessage = victoryMessage..", a new PB!"
				end
				Strategies.tweetProgress(victoryMessage)
				if Strategies.seed then
					print("v"..VERSION..": "..Utils.frames().." frames, with seed "..Strategies.seed)
					print("Please save this seed number to share, if you would like proof of your run!")
					print("A screenshot has been saved to the Gameboy\\Screenshots folder in BizHawk.")

					if STREAMING_MODE and not Strategies.replay then
						gui.cleartext()
						gui.text(0, 0, "PokeBot v"..VERSION)
						gui.text(0, 7, "Seed: "..Strategies.seed)
						gui.text(0, 14, "Name: "..Textbox.getNamePlaintext())
						gui.text(0, 21, "Reset for time: "..tostring(RESET_FOR_TIME))
						gui.text(0, 28, "Time: "..Utils.elapsedTime())
						gui.text(0, 35, "Frames: "..Utils.frames())
						client.setscreenshotosd(true)
						client.screenshot()
						client.setscreenshotosd(false)
						gui.cleartext()
					end
				end
			elseif status.frames == 500 then
				Bridge.chat("beat the game in "..status.finishTime.."!")
			elseif status.frames > 2000 then
				return Strategies.hardReset("Back to the grind - you can follow on Twitter for updates on our next good run! https://twitter.com/thepokebot")
			end
			status.frames = status.frames + 1
		elseif Memory.value("menu", "shop_current") == 252 then
			strategyFunctions.split({finished=true})
			status.finishTime = Utils.elapsedTime()
		else
			Input.cancel()
		end
	end,

}

strategyFunctions = Strategies.functions

function Strategies.execute(data)
	local strategyFunction = strategyFunctions[data.s]
	if not strategyFunction then
		p("INVALID STRATEGY", data.s, GAME_NAME)
		return true
	end
	if strategyFunction(data) then
		status = {tries=0}
		Strategies.status = status
		Strategies.completeGameStrategy()
		if yellow then
			-- print(data.s)
		end
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
		Control.preferredPotion = "super"
		Combat.factorPP(true)
	end
	Strategies.initGame(midGame)
end

function Strategies.softReset()
	status = {tries=0}
	Strategies.status = status
	stats = {}
	Strategies.stats = stats
	Strategies.updates = {}

	splitNumber, splitTime = 0, 0
	resetting = nil
	Strategies.deepRun = false
	Strategies.resetGame()
end

return Strategies
