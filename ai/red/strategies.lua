local strategies = require "ai.strategies"

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

local level4Nidoran = true -- 57 vs 96 (d39)
local nidoAttack, nidoSpeed, nidoSpecial = 0, 0, 0
local squirtleAtt, squirtleDef, squirtleSpd, squirtleScl
local riskGiovanni, maxEtherSkip

local status = strategies.status

strategies.timeRequirements = {

	bulbasaur = function()
		return 2.25
	end,

	nidoran = function()
		local timeLimit = 6.33
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
		local timeLimit = 32.5
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	goldeen = function()
		local timeLimit = 37.5
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	misty = function()
		local timeLimit = 39.5
		if pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	vermilion = function()
		return 44
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

	victory_road = function()
		return 98.75 -- PB
	end,

	e4center = function()
		return 102
	end,

	blue = function()
		return 108.5
	end,

}

-- HELPERS

local function nidoranDSum(disabled)
	local sx, sy = player.position()
	if not disabled and status.tries == nil then
		local opponentName = battle.opponent()
		local opLevel = memory.value("battle", "opponent_level")
		if opponentName == "rattata" then
			if opLevel == 2 then
				status.tries = {0, 4, 12}
			elseif opLevel == 3 then
				status.tries = {0, 14, 11}
			else
				-- status.tries = {0, 0, 10} -- TODO can't escape
			end
		elseif opponentName == "spearow" then
			if opLevel == 5 then
				-- can't escape
			end
		elseif opponentName == "nidoran" then
			status.tries = {0, 6, 12}
		elseif opponentName == "nidoranf" then
			if opLevel == 3 then
				status.tries = {4, 6, 12}
			else
				status.tries = {5, 6, 12}
			end
		end
		if status.tries then
			status.tries.idx = 1
			status.tries.x, status.tries.y = sx, sy
		else
			status.tries = 0
		end
	end
	if not disabled and status.tries ~= 0 then
		if status.tries[tries.idx] == 0 then
			status.tries.idx = status.tries.idx + 1
			if status.tries.idx > 3 then
				status.tries = 0
			end
			return nidoranDSum()
		end
		if status.tries.x ~= sx or status.tries.y ~= sy then
			status.tries[tries.idx] = status.tries[tries.idx] - 1
			status.tries.x, status.tries.y = sx, sy
		end
		if status.tries.idx == 2 then
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

-- STRATEGIES

local strategyFunctions = strategies.functions

-- General

strategyFunctions.tweetMisty = function()
	if not strategies.setYolo("misty") then
		local timeLimit = strategies.getTimeRequirement("misty")
		if not strategies.overMinute(timeLimit - 0.5) then
			local pbn = ""
			if not strategies.overMinute(timeLimit - 1) then
				pbn = " (PB pace)"
			end
			local elt = utils.elapsedTime()
			bridge.tweet("Got a run going, just beat Misty "..elt.." in"..pbn.." http://www.twitch.tv/thepokebot")
		end
	end
	return true
end

strategyFunctions.tweetVictoryRoad = function()
	local elt = utils.elapsedTime()
	local pbn = ""
	if not strategies.overMinute(strategies.getTimeRequirement("victory_road")) then
		pbn = " (PB pace)"
	end
	local elt = utils.elapsedTime()
	bridge.tweet("Entering Victory Road at "..elt..pbn.." on our way to the Elite Four http://www.twitch.tv/thepokebot")
	return true
end

strategyFunctions.fightXAccuracy = function()
	return strategies.prepare("x_accuracy")
end

-- Route

strategyFunctions.squirtleIChooseYou = function()
	if pokemon.inParty("squirtle") then
		bridge.caught("squirtle")
		return true
	end
	if player.face("Up") then
		textbox.name("A")
	end
end

strategyFunctions.fightBulbasaur = function()
	if status.tries < 9000 and pokemon.index(0, "level") == 6 then
		if status.tries > 200 then
			squirtleAtt = pokemon.index(0, "attack")
			squirtleDef = pokemon.index(0, "defense")
			squirtleSpd = pokemon.index(0, "speed")
			squirtleScl = pokemon.index(0, "special")
			if squirtleAtt < 11 and squirtleScl < 12 then
				return strategies.reset("Bad Squirtle - "..squirtleAtt.." attack, "..squirtleScl.." special")
			end
			status.tries = 9001
		else
			status.tries = status.tries + 1
		end
	end
	if battle.isActive() and memory.double("battle", "opponent_hp") > 0 and strategies.resetTime(strategies.getTimeRequirement("bulbasaur"), "kill Bulbasaur") then
		return true
	end
	return strategies.buffTo("tail_whip", 6)
end

-- dodgePalletBoy

strategyFunctions.shopViridianPokeballs = function()
	return shop.transaction{
		buy = {{name="pokeball", index=0, amount=8}}
	}
end

strategyFunctions.catchNidoran = function()
	if not control.canCatch() then
		return true
	end
	local pokeballs = inventory.count("pokeball")
	local caught = memory.value("player", "party_size") - 1
	if pokeballs < 5 - caught * 2 then
		return strategies.reset("Ran too low on PokeBalls", pokeballs)
	end
	if battle.isActive() then
		local isNidoran = pokemon.isOpponent("nidoran")
		if isNidoran and memory.value("battle", "opponent_level") > 2 then
			if strategies.initialize() then
				bridge.pollForName()
			end
		end
		status.tries = nil
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

		local timeLimit = strategies.getTimeRequirement("nidoran")
		local resetMessage
		if hasNidoran then
			resetMessage = "get an experience kill before Brock"
		else
			resetMessage = "find a suitable Nidoran"
		end
		if strategies.resetTime(timeLimit, resetMessage) then
			return true
		end
		if not noDSum and strategies.overMinute(timeLimit - 0.25) then
			noDSum = true
		end
		nidoranDSum(noDSum)
	end
end

-- 1: NIDORAN

strategyFunctions.dodgeViridianOldMan = function()
	return strategies.dodgeUp(0x0273, 18, 6, 17, 9)
end

strategyFunctions.grabTreePotion = function()
	if strategies.initialize() then
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
end

strategyFunctions.grabAntidote = function()
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
end

strategyFunctions.grabForestPotion = function()
	if battle.handleWild() then
		local potionCount = inventory.count("potion")
		if strategies.initialize() then
			tempDir = potionCount
		end
		if potionCount > 0 then
			if tempDir and potionCount > tempDir then
				tempDir = nil
			end
			local healthNeeded = (pokemon.info("spearow", "level") == 3) and 8 or 15
			if pokemon.info("squirtle", "hp") <= healthNeeded then
				if menu.pause() then
					inventory.use("potion", "squirtle")
				end
			else
				return true
			end
		elseif not tempDir then
			return true
		elseif menu.close() then
			player.interact("Up")
		end
	end
end

strategyFunctions.fightWeedle = function()
	if battle.isTrainer() then
		canProgress = true
		local squirtleOut = pokemon.isDeployed("squirtle")
		if squirtleOut and memory.value("battle", "our_status") > 0 and not inventory.contains("antidote") then
			return strategies.reset("Poisoned, but we skipped the antidote")
		end
		local sidx = pokemon.indexOf("spearow")
		if sidx ~= -1 and pokemon.index(sidx, "level") > 3 then
			sidx = -1
		end
		if sidx == -1 then
			return strategies.buffTo("tail_whip", 5)
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
end

strategyFunctions.equipForBrock = function(data)
	if strategies.initialize() then
		if pokemon.info("squirtle", "level") < 8 then
			local message, wait
			if pokemon.info("spearow", "level") == 3 then
				message = "Lost too much exp accidentally killing Weedle with Spearow"
			else
				message = "Did not reach level 8 before Brock"
				wait = true
			end
			return strategies.reset(message, pokemon.getExp(), wait)
		end
		if data.anti then
			local poisoned = pokemon.info("squirtle", "status") > 0
			if not poisoned then
				return true
			end
			if not inventory.contains("antidote") then
				return strategies.reset("Poisoned, but we risked skipping the antidote")
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
			elseif main == 103 then --TODO check loop
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
end

strategyFunctions.fightBrock = function()
	local squirtleHP = pokemon.info("squirtle", "hp")
	if squirtleHP == 0 then
		return strategies.death()
	end
	if battle.isActive() then
		if status.tries < 1 then
			status.tries = 1
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
			if status.tries < 9000 then
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
					if status.tries > 300 then
						local statDiff = (16 - att) + (15 - spd) + (13 - scl)
						if not level4Nidoran then
							statDiff = statDiff + 1
						end
						local resets = att < 15 or spd < 14 or scl < 12 or (att == 15 and spd == 14)
						local nStatus = "Att: "..att..", Def: "..def..", Speed: "..spd..", Special: "..scl
						if resets then
							return strategies.reset("Bad Nidoran - "..nStatus)
						end
						status.tries = 9001

						if def < 12 then
							statDiff = statDiff + 1
						end
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
						elseif statDiff <= 3 then
							superlative = "n okay"
							exclaim = "."
						else
							superlative = " min stat"
							exclaim = "."
						end
						nStatus = "Beat Brock with a"..superlative.." Nidoran"..exclaim.." "..nStatus..", caught at level "..(level4Nidoran and "4" or "3").."."
						bridge.chat(nStatus)
					else
						status.tries = status.tries + 1
					end
				end
			end
		end
	elseif status.tries > 0 then
		return true
	elseif textbox.handle() then
		player.interact("Up")
	end
end

-- 2: BROCK

strategyFunctions.shopPewterMart = function()
	return shop.transaction{
		buy = {{name="potion", index=1, amount=9}}
	}
end

strategyFunctions.battleModeSet = function()
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
end

strategyFunctions.leer = function(data)
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
	return strategies.buffTo("leer", defLimit)
end

strategyFunctions.bugCatcher = function()
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
		strategies.functions.leer({{"caterpie",8}, {"weedle",7}})
	elseif canProgress then
		return true
	else
		battle.automate()
	end
end

strategyFunctions.shortsKid = function()
	local fightingEkans = pokemon.isOpponent("ekans")
	if fightingEkans then
		local wrapping = memory.value("battle", "turns") > 0
		if wrapping then
			local curr_hp = memory.double("battle", "our_hp")
			if not tempDir then
				tempDir = curr_hp
			end
			local wrapDamage = tempDir - curr_hp
			if wrapDamage > 0 and wrapDamage < 7 and curr_hp < 14 and not strategies.opponentDamaged() then
				inventory.use("potion", nil, true)
				return false
			end
		elseif tempDir then
			tempDir = nil
		end
	end
	control.battlePotion(fightingEkans or strategies.damaged(2))
	return strategies.functions.leer({{"rattata",9}, {"ekans",10}})
end

strategyFunctions.potionBeforeCocoons = function()
	if nidoSpeed >= 15 then
		return true
	end
	return strategies.functions.potion({hp=6, yolo=3})
end

strategyFunctions.swapHornAttack = function()
	if pokemon.battleMove("horn_attack") == 1 then
		return true
	end
	battle.swapMove(1, 3)
end

strategyFunctions.fightMetapod = function()
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
end

strategyFunctions.catchFlierBackup = function()
	if strategies.initialize() then
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
end

-- 3: ROUTE 3

strategyFunctions.startMtMoon = function()
	control.moonEncounters = 0
	control.canDie(false)
	return true
end

strategyFunctions.evolveNidorino = function()
	if pokemon.inParty("nidorino") then
		bridge.caught("nidorino")
		return true
	end
	if battle.isActive() then
		status.tries = 0
		canProgress = true
		if memory.double("battle", "opponent_hp") == 0 then
			input.press("A")
		else
			battle.automate()
		end
	elseif status.tries > 3600 then
		print("Broke from Nidorino on tries")
		return true
	else
		if canProgress then
			status.tries = status.tries + 1
		end
		input.press("A")
	end
end

strategyFunctions.evolveNidoking = function()
	if battle.handleWild() then
		if not inventory.contains("moon_stone") then
			if strategies.initialize() then
				bridge.caught("nidoking")
			end
			if menu.close() then
				return true
			end
		elseif not inventory.use("moon_stone") then
			menu.pause()
		end
	end
end

-- helix

strategyFunctions.reportMtMoon = function()
	if battle.pp("horn_attack") == 0 then
		print("ERR: Ran out of Horn Attacks")
	end
	if control.moonEncounters then
		local parasStatus
		local conjunction = "but"
		local goodEncounters = control.moonEncounters < 10
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
		bridge.chat(control.moonEncounters.." Moon encounters, "..conjunction.." "..parasStatus)
		control.moonEncounters = nil
	end

	local timeLimit = strategies.getTimeRequirement("mt_moon")
	strategies.resetTime(timeLimit, "complete Mt. Moon", true)
	return true
end

-- 4: MT. MOON

-- dodgeCerulean

-- dodgeCeruleanLeft

strategyFunctions.rivalSandAttack = function(data)
	if battle.isActive() then
		if battle.redeployNidoking() then
			return false
		end
		local opponent = battle.opponent()
		if memory.value("battle", "accuracy") < 7 then
			local sacrifice
			if opponent == "pidgeotto" then
				local __, turns = combat.bestMove()
				if turns == 1 then
					sacrifice = pokemon.getSacrifice("pidgey", "spearow", "paras", "oddish", "squirtle")
				end
			elseif opponent == "raticate" then
				sacrifice = pokemon.getSacrifice("pidgey", "spearow", "oddish")
			end
			if battle.sacrifice(sacrifice) then
				return false
			end
		end

		if opponent == "pidgeotto" then
			combat.disableThrash = true
		elseif opponent == "raticate" then
			combat.disableThrash = strategies.opponentDamaged() or (not control.yolo and pokemon.index(0, "hp") < 32) -- RISK
		elseif opponent == "ivysaur" then
			if not control.yolo and strategies.damaged(5) and inventory.contains("super_potion") then
				inventory.use("super_potion", nil, true)
				return false
			end
			combat.disableThrash = strategies.opponentDamaged()
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
end

strategyFunctions.teachThrash = function()
	if strategies.initialize() then
		if pokemon.hasMove("thrash") or pokemon.info("nidoking", "level") < 21 then
			return true
		end
	end
	if strategies.functions.teach({move="thrash",item="rare_candy",replace="leer"}) then
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
end

strategyFunctions.potionForMankey = function()
	if strategies.initialize() then
		if pokemon.info("nidoking", "level") > 20 then
			return true
		end
	end
	return strategies.functions.potion({hp=18, yolo=8})
end

strategyFunctions.redbarMankey = function()
	if not strategies.setYolo("mankey") then
		return true
	end
	local curr_hp, red_hp = pokemon.index(0, "hp"), strategies.redHP()
	if curr_hp <= red_hp then
		return true
	end
	if strategies.initialize() then
		if pokemon.info("nidoking", "level") < 23 or inventory.count("potion") < 3 then -- RISK
			return true
		end
		bridge.chat("Using Poison Sting to attempt to red-bar off Mankey")
	end
	if battle.isActive() then
		canProgress = true
		local enemyMove, enemyTurns = combat.enemyAttack()
		if enemyTurns then
			if enemyTurns < 2 then
				return true
			end
			local scratchDmg = enemyMove.damage
			if curr_hp - scratchDmg >= red_hp then
				return true
			end
		end
		battle.automate("poison_sting")
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

strategyFunctions.thrashGeodude = function()
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
end

strategyFunctions.potionBeforeGoldeen = function()
	if strategies.initialize() then
		if strategies.setYolo("goldeen") or pokemon.index(0, "hp") > 7 then
			return true
		end
	end
	return strategies.functions.potion({hp=64, chain=true})
end

strategyFunctions.potionBeforeMisty = function()
	local healAmount = 70
	if control.yolo then
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
	if strategies.initialize() then
		local message
		local potionCount = inventory.count("potion")
		local needsToHeal = healAmount - pokemon.index(0, "hp")
		if potionCount * 20 < needsToHeal then
			message = "Ran too low on potions to heal enough before Misty"
		elseif healAmount < 60 then
			message = "Limiting heals to attempt to get closer to red-bar off Misty"
		end
		if message then
			bridge.chat(message, potionCount)
		end
	end
	return strategies.functions.potion({hp=healAmount})
end

strategyFunctions.fightMisty = function()
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
end

-- 6: MISTY

strategyFunctions.potionBeforeRocket = function()
	local minAttack = 55 -- RISK
	if control.yolo then
		minAttack = minAttack - 1
	end
	if nidoAttack >= minAttack then
		return true
	end
	return strategies.functions.potion({hp=10})
end

strategyFunctions.jingleSkip = function()
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
end

strategyFunctions.catchOddish = function()
	if not control.canCatch() then
		return true
	end
	local caught = pokemon.inParty("oddish", "paras")
	local battleValue = memory.value("game", "battle")
	local px, py = player.position()
	if battleValue > 0 then
		if battleValue == 2 then
			status.tries = 2
			battle.automate()
		else
			if status.tries == 0 and py == 31 then
				status.tries = 1
			end
			if not control.shouldCatch() then
				battle.run()
			end
		end
	elseif status.tries == 1 and py == 31 then
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
end

strategyFunctions.shopVermilionMart = function()
	if strategies.initialize() then
		strategies.setYolo("vermilion")
	end
	local buyArray, sellArray
	if not inventory.contains("pokeball") or (not control.yolo and nidoAttack < 53) then
		sellArray = {{name="pokeball"}, {name="antidote"}, {name="tm34"}, {name="nugget"}}
		buyArray = {{name="super_potion",index=1,amount=3}, {name="paralyze_heal",index=4,amount=2}, {name="repel",index=5,amount=3}}
	else
		sellArray = {{name="antidote"}, {name="tm34"}, {name="nugget"}}
		buyArray = {{name="super_potion",index=1,amount=3}, {name="repel",index=5,amount=3}}
	end
	return shop.transaction {
		sell = sellArray,
		buy = buyArray
	}
end

-- rivalSandAttack

strategyFunctions.trashcans = function()
	local progress = memory.value("progress", "trashcans")
	if textbox.isActive() then
		if not canProgress then
			if progress < 2 then
				status.tries = status.tries + 1
			end
			canProgress = true
		end
		input.cancel()
	else
		if progress == 3 then
			local px, py = player.position()
			if px == 4 and py == 6 then
				status.tries = status.tries + 1
				local timeLimit = strategies.getTimeRequirement("trash") + 1.5
				if strategies.resetTime(timeLimit, "complete Trashcans ("..status.tries.." tries)") then
					return true
				end
				strategies.setYolo("trash")

				local prefix
				local suffix = "!"
				if status.tries < 2 then
					prefix = "PERFECT"
				elseif status.tries < 4 then
					prefix = "Amazing"
				elseif status.tries < 7 then
					prefix = "Great"
				elseif status.tries < 10 then
					prefix = "Good"
				elseif status.tries < 24 then
					prefix = "Ugh"
					suffix = "."
				else -- TODO trashcans WR
					prefix = "Reset me now"
					suffix = " BibleThump"
				end
				bridge.chat(prefix..", "..status.tries.." try Trashcans"..suffix, utils.elapsedTime())
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
			local trashPath = {{2,11},{"Left"},{2,11}, {2,12},{4,12},{4,11},{"Right"},{4,11}, {4,9},{"Left"},{4,9}, {4,7},{"Right"},{4,7}, {4,6},{2,6},{2,7},{"Left"},{2,7}, {2,6},{4,6},{4,8},{9,8},{"Up"},{9,8}, {8,8},{8,9},{"Left"},{8,9}, {8,10},{9,10},{"Down"},{9,10},{8,10}}
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
end

strategyFunctions.fightSurge = function()
	if battle.isActive() then
		canProgress = true
		local forced
		if pokemon.isOpponent("voltorb") then
			combat.disableThrash = true
			local __, enemyTurns = combat.enemyAttack()
			if not enemyTurns or enemyTurns > 2 then
				forced = "bubblebeam"
			elseif enemyTurns == 2 and not strategies.opponentDamaged() then
				local curr_hp, red_hp = pokemon.index(0, "hp"), strategies.redHP()
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
end

-- 7: SURGE

strategyFunctions.procureBicycle = function()
	if inventory.contains("bicycle") then
		if not textbox.isActive() then
			return true
		end
		input.cancel()
	elseif textbox.handle() then
		player.interact("Right")
	end
end

strategyFunctions.swapBicycle = function()
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
end

strategyFunctions.redbarCubone = function()
	if battle.isActive() then
		local forced
		canProgress = true
		if pokemon.isOpponent("cubone") then
			local enemyMove, enemyTurns = combat.enemyAttack()
			if enemyTurns then
				local curr_hp, red_hp = pokemon.index(0, "hp"), strategies.redHP()
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
				if forced and strategies.initialize() then
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
end

strategyFunctions.shopTM07 = function()
	return shop.transaction{
		direction = "Up",
		buy = {{name="horn_drill", index=3}}
	}
end

strategyFunctions.shopRepels = function()
	return shop.transaction{
		direction = "Up",
		buy = {{name="super_repel", index=3, amount=9}}
	}
end

strategyFunctions.shopPokeDoll = function()
	return shop.transaction{
		direction = "Down",
		buy = {{name="pokedoll", index=0}}
	}
end

strategyFunctions.shopVending = function()
	return shop.vend{
		direction = "Up",
		buy = {{name="fresh_water", index=0}, {name="soda_pop", index=1}}
	}
end

strategyFunctions.giveWater = function()
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
end

strategyFunctions.shopExtraWater = function()
	return shop.vend{
		direction = "Up",
		buy = {{name="fresh_water", index=0}}
	}
end

strategyFunctions.shopBuffs = function()
	if strategies.initialize() then
		local minSpecial = 45
		if control.yolo then
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
end

strategyFunctions.deptElevator = function()
	if textbox.isActive() then
		canProgress = true
		menu.select(0, false)
	else
		if canProgress then
			return true
		end
		player.interact("Up")
	end
end

strategyFunctions.swapRepels = function()
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
end

-- 8: FLY

strategyFunctions.lavenderRival = function()
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
		if pokemon.isOpponent("gyarados") or strategies.prepare("x_accuracy") then
			battle.automate()
		end
	elseif canProgress then
		return true
	else
		input.cancel()
	end
end

strategyFunctions.pokeDoll = function()
	if battle.isActive() then
		canProgress = true
		inventory.use("pokedoll", nil, true)
	elseif canProgress then
		return true
	else
		input.cancel()
	end
end

strategyFunctions.digFight = function()
	if battle.isActive() then
		canProgress = true
		local currentlyDead = memory.double("battle", "our_hp") == 0
		if currentlyDead then
			local backupPokemon = pokemon.getSacrifice("paras", "squirtle")
			if not backupPokemon then
				return strategies.death()
			end
			if utils.onPokemonSelect(memory.value("battle", "menu")) then
				menu.select(pokemon.indexOf(backupPokemon), true)
			else
				input.press("A")
			end
		else
			battle.automate()
		end
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

strategyFunctions.thunderboltFirst = function()
	local forced
	if pokemon.isOpponent("zubat") then
		canProgress = true
		forced = "thunderbolt"
	elseif canProgress then
		return true
	end
	battle.automate(forced)
end

-- 8: POKÉFLUTE

-- playPokeflute

strategyFunctions.drivebyRareCandy = function()
	if textbox.isActive() then
		canProgress = true
		input.cancel()
	elseif canProgress then
		return true
	else
		local px, py = player.position()
		if py < 13 then
			status.tries = 0
			return
		end
		if py == 13 and status.tries % 2 == 0 then
			input.press("A", 2)
		else
			input.press("Up")
			status.tries = 0
		end
		status.tries = status.tries + 1
	end
end

strategyFunctions.safariCarbos = function()
	if strategies.initialize() then
		strategies.setYolo("safari_carbos")
	end
	local minSpeed = 50
	if control.yolo then
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
end

strategyFunctions.centerSkipFullRestore = function()
	if strategies.initialize() then
		if control.yolo or inventory.contains("full_restore") then
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
		return strategies.functions.interact({dir="Down"})
	end
	walk.step(px, py)
end

strategyFunctions.silphElevator = function()
	if textbox.isActive() then
		canProgress = true
		menu.select(9, false, true)
	else
		if canProgress then
			return true
		end
		player.interact("Up")
	end
end

strategyFunctions.fightSilphMachoke = function()
	if battle.isActive() then
		canProgress = true
		if nidoSpecial > 44 then
			return strategies.prepare("x_accuracy")
		end
		battle.automate("thrash")
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

strategyFunctions.silphCarbos = function()
	if nidoSpeed > 50 then
		return true
	end
	return strategies.functions.interact({dir="Left"})
end

strategyFunctions.silphRival = function()
	if battle.isActive() then
		if strategies.initialize() then
			tempDir = combat.healthFor("RivalGyarados")
			canProgress = true
		end
		local gyaradosDamage = tempDir

		local forced
		local readyToAttack = false
		local opponentName = battle.opponent()
		if opponentName == "gyarados" then
			readyToAttack = true
			local hp, red_hp = pokemon.index(0, "hp"), strategies.redHP()
			if hp > gyaradosDamage * 0.98 and hp - gyaradosDamage * 0.975 < red_hp then --TODO
				if strategies.prepare("x_special") then
					forced = "ice_beam"
				else
					readyToAttack = false
				end
			elseif strategies.isPrepared("x_special") then
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
		elseif strategies.prepare("x_accuracy", "x_speed") then
			if opName == "pidgeot" then
				if nidoSpecial < 45 or strategies.hasHealthFor("KogaWeezing", 10) then --TODO remove for red bar
					forced = "thunderbolt"
				end
			elseif opponentName == "alakazam" or opponentName == "growlithe" then
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
end

strategyFunctions.potionBeforeGiovanni = function()
	-- TODO verify newly leveled
	-- local curr_hp = pokemon.index(0, "hp")
	-- if curr_hp < 16 and pokemon.index(0, "level") == 37 then
	-- 	local rareCandyCount = inventory.count("rare_candy")
	-- 	if rareCandyCount > 2 then
	-- 		if menu.pause() then
	-- 			inventory.use("rare_candy", nil, false)
	-- 		end
	-- 		return false
	-- 	end
	-- end
	return strategies.functions.potion({hp=16, yolo=12, close=true})
end

strategyFunctions.fightSilphGiovanni = function()
	if battle.isActive() then
		canProgress = true
		local forced
		local opponentName = battle.opponent()
		if opponentName == "nidorino" then
			if battle.pp("horn_drill") > 2 then
				forced = "horn_drill"
			else
				forced = "earthquake"
			end
		elseif opponentName == "rhyhorn" then
			forced = "ice_beam"
		elseif opponentName == "kangaskhan" or opponentName == "nidoqueen" then
			forced = "horn_drill"
		end
		battle.automate(forced)
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

--	9: SILPH CO.

strategyFunctions.potionBeforeHypno = function()
	local curr_hp, red_hp = pokemon.index(0, "hp"), strategies.redHP()
	local healthUnderRedBar = red_hp - curr_hp
	local yoloHP = combat.healthFor("HypnoHeadbutt") * 0.9
	local useRareCandy = inventory.count("rare_candy") > 2

	local healTarget
	if healthUnderRedBar >= 0 then
		healTarget = "HypnoHeadbutt"
		if useRareCandy then
			useRareCandy = healthUnderRedBar > 2
		end
	else
		healTarget = "HypnoConfusion"
		if useRareCandy then
			useRareCandy = false --TODO
			-- useRareCandy = curr_hp < combat.healthFor("KogaWeezing") * 0.85
		end
	end
	if useRareCandy then
		if menu.pause() then
			inventory.use("rare_candy", nil, false)
		end
		return false
	end

	return strategies.functions.potion({hp=healTarget, yolo=yoloHP, close=true})
end

strategyFunctions.fightHypno = function()
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
end

strategyFunctions.fightKoga = function() --TODO x-accuracy?
	if battle.isActive() then
		local forced
		if pokemon.isOpponent("weezing") then
			if strategies.opponentDamaged(2) then
				inventory.use("pokeflute", nil, true)
				return false
			end
			if combat.isDisabled(85) then
				forced = "ice_beam"
			else
				forced = "thunderbolt"
			end
			control.canDie(true)
		end
		battle.automate(forced)
		canProgress = true
	elseif canProgress then
		strategies.deepRun = true
		return true
	else
		textbox.handle()
	end
end

-- 10: KOGA

strategyFunctions.dodgeGirl = function()
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
end

strategyFunctions.cinnabarCarbos = function()
	local px, py = player.position()
	if px == 21 then
		return true
	end
	local minSpeed = 51
	if control.yolo then
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
end

strategyFunctions.fightErika = function()
	if battle.isActive() then
		canProgress = true
		local forced
		local curr_hp, red_hp = pokemon.index(0, "hp"), strategies.redHP()
		local razorDamage = 34
		if curr_hp > razorDamage and curr_hp - razorDamage < red_hp then
			if strategies.opponentDamaged() then
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
end

-- 11: ERIKA

strategyFunctions.waitToReceive = function()
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
end

-- 14: SABRINA

strategyFunctions.earthquakeElixer = function(data)
	if battle.pp("earthquake") >= data.min then
		if strategies.closeMenuFor(data) then
			return true
		end
		return false
	end
	if strategies.initialize() then
		print("EQ Elixer: "..control.areaName)
	end
	return strategies.useItem({item="elixer", poke="nidoking", chain=data.chain, close=data.close})
end

strategyFunctions.fightGiovanniMachoke = function()
	if strategies.initialize() then
		if nidoAttack >= 55 then
			local eqPpRequired = nidoSpecial >= 47 and 7 or 8
			if battle.pp("earthquake") >= eqPpRequired then
				bridge.chat("Using Earthquake strats on the Machokes")
				return true
			end
		end
	end
	return strategies.prepare("x_special")
end

strategyFunctions.checkGiovanni = function()
	local ryhornDamage = math.floor(combat.healthFor("GiovanniRhyhorn") * 0.95) --RISK
	if strategies.initialize() then
		local earthquakePP = battle.pp("earthquake")
		if earthquakePP >= 2 then
			if riskGiovanni then
				if earthquakePP >= 5 then
					bridge.chat("Saved enough Earthquake PP for safe strats on Giovanni")
				elseif earthquakePP >= 3 and battle.pp("horn_drill") >= 5 and (control.yolo or pokemon.info("nidoking", "hp") >= ryhornDamage) then -- RISK
					bridge.chat("Using risky strats on Giovanni to skip the extra Max Ether...")
				else
					riskGiovanni = false
				end
			end
			return true
		end
		local message = "Ran out of Earthquake PP :( "
		if control.yolo then
			message = message.."Risking on Giovanni."
		else
			message = message.."Time for standard strats."
		end
		bridge.chat(message)
		riskGiovanni = false
	end
	return strategies.functions.potion({hp=50, yolo=ryhornDamage})
end

strategyFunctions.fightGiovanni = function()
	if battle.isActive() then
		if strategies.initialize() then
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
		if needsXSpecial and not strategies.prepare("x_special") then
			return false
		end
		battle.automate(forced)
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

-- 15: GIOVANNI

strategyFunctions.viridianRival = function()
	if battle.isActive() then
		if not canProgress then
			if riskGiovanni or nidoSpecial < 45 or pokemon.index(0, "speed") < 134 then
				tempDir = "x_special"
			else
				print("Skip X Special strats!")
			end
			canProgress = true
		end
		if strategies.prepare("x_accuracy", tempDir) then
			local forced
			if pokemon.isOpponent("pidgeot") then
				forced = "thunderbolt"
			elseif riskGiovanni then
				if pokemon.isOpponent("rhyhorn") or strategies.opponentDamaged() then
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
end

strategyFunctions.ether = function(data)
	local main = memory.value("menu", "main")
	data.item = tempDir
	if tempDir and strategies.completedMenuFor(data) then
		if strategies.closeMenuFor(data) then
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
			status.tries = inventory.count(tempDir) --TODO remove?
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
end

strategyFunctions.pickMaxEther = function()
	if not canProgress then
		if maxEtherSkip then
			return true
		end
		if memory.value("player", "moving") == 0 then
			if player.isFacing("Right") then
				canProgress = true
			end
			status.tempDir = not tempDir
			if status.tempDir then
				input.press("Right", 1)
			end
		end
		return false
	end
	if inventory.contains("max_ether") then
		return true
	end
	player.interact("Right")
end

-- push

strategyFunctions.potionBeforeLorelei = function()
	if strategies.initialize() then
		local canPotion
		if inventory.contains("potion") and strategies.hasHealthFor("LoreleiDewgong", 20) then
			canPotion = true
		elseif inventory.contains("super_potion") and strategies.hasHealthFor("LoreleiDewgong", 50) then
			canPotion = true
		end
		if not canPotion then
			return true
		end
		bridge.chat("Healing before Lorelei to skip the Elite 4 Center...")
	end
	return strategies.functions.potion({hp=combat.healthFor("LoreleiDewgong")})
end

strategyFunctions.depositPokemon = function()
	local toSize
	if strategies.hasHealthFor("LoreleiDewgong") then
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
				local menuColumn = menu.getCol()
				if menuColumn == 10 then
					input.press("A")
				elseif menuColumn == 5 then
					local depositIndex = 1
					local depositAllExtras = toSize == 1
					if not depositAllExtras and pokemon.indexOf("pidgey", "spearow") == 1 then
						depositIndex = 2
					end
					menu.select(depositIndex)
				else
					menu.select(1)
				end
			else
				input.press("A")
			end
		end
	end
end

strategyFunctions.centerSkip = function()
	strategies.setYolo("e4center")
	local message = "Skipping the Center and attempting to red-bar "
	if strategies.hasHealthFor("LoreleiDewgong") then
		message = message.."off Lorelei..."
	else
		message = message.."the Elite 4!"
	end
	bridge.chat(message)
	return true
end

strategyFunctions.lorelei = function()
	if battle.isActive() then
		canProgress = true
		if battle.redeployNidoking() then
			return false
		end
		local forced
		local opponentName = battle.opponent()
		if opponentName == "dewgong" then
			if battle.sacrifice("pidgey", "spearow", "squirtle", "paras", "oddish") then
				return false
			end
		elseif opponentName == "jinx" then
			if battle.pp("horn_drill") < 2 then
				forced = "earthquake"
			end
		end
		if strategies.prepare("x_accuracy") then
			battle.automate(forced)
		end
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

-- 16: LORELEI

strategyFunctions.bruno = function()
	if battle.isActive() then
		canProgress = true
		local forced
		if pokemon.isOpponent("onix") then
			forced = "ice_beam"
			-- local curr_hp, red_hp = pokemon.info("nidoking", "hp"), strategies.redHP()
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
		if strategies.prepare("x_accuracy") then
			battle.automate(forced)
		end
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

strategyFunctions.agatha = function() --TODO test without x acc
	if battle.isActive() then
		canProgress = true
		if combat.isSleeping() then
			inventory.use("pokeflute", nil, true)
			return false
		end
		if pokemon.isOpponent("gengar") then
			local currentHP = pokemon.info("nidoking", "hp")
			if not control.yolo and currentHP <= 56 and not strategies.isPrepared("x_speed") then
				local toPotion = inventory.contains("full_restore", "super_potion")
				if toPotion then
					inventory.use(toPotion, nil, true)
					return false
				end
			end
			if not strategies.prepare("x_speed") then
				return false
			end
		end
		battle.automate()
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

strategyFunctions.prepareForLance = function()
	local enableFull
	if strategies.hasHealthFor("LanceGyarados", 100) then
		enableFull = inventory.count("super_potion") < 2
	elseif strategies.hasHealthFor("LanceGyarados", 50) then
		enableFull = not inventory.contains("super_potion")
	else
		enableFull = true
	end
	local min_recovery = combat.healthFor("LanceGyarados")
	return strategies.functions.potion({hp=min_recovery, full=enableFull, chain=true})
end

strategyFunctions.lance = function()
	if battle.isActive() then
		canProgress = true
		local xItem
		if pokemon.isOpponent("dragonair") then
			xItem = "x_speed"
		else
			xItem = "x_special"
		end
		if strategies.prepare(xItem) then
			battle.automate()
		end
	elseif canProgress then
		return true
	else
		textbox.handle()
	end
end

strategyFunctions.prepareForBlue = function()
	if strategies.initialize() then
		strategies.setYolo("blue")
	end
	local skyDmg = combat.healthFor("BlueSky") * 0.925
	local wingDmg = combat.healthFor("BluePidgeot")
	return strategies.functions.potion({hp=skyDmg-50, yolo=wingDmg, full=true})
end

strategyFunctions.blue = function()
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
			if strategies.initialize() then
				if not strategies.isPrepared("x_accuracy", tempDir) then
					local msg = "Uh oh... First-turn Sky Attack could end the run here, "
					if pokemon.index(0, "hp") > skyDamage then
						msg = msg.."no criticals pls D:"
					elseif strategies.canHealFor(healCutoff) then
						msg = msg.."attempting to heal for it"
						if not strategies.canHealFor(skyDamage) then
							msg = msg.." (damage range)"
						end
						msg = msg.."."
					else
						msg = msg.."and nothing left to heal with BibleThump"
					end
					bridge.chat(msg)
				end
			end

			if strategies.prepare(firstItem) then
				if not strategies.isPrepared(secondItem) then
					local toPotion = strategies.canHealFor(healCutoff)
					if toPotion then
						inventory.use(toPotion, nil, true)
						return false
					end
				end
				if strategies.prepare("x_accuracy", tempDir) then
					battle.automate(forced)
				end
			end
		else
			if strategies.prepare(firstItem, secondItem) then
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
end

strategyFunctions.champion = function()
	if canProgress then
		if status.tries > 1500 then
			return strategies.hardReset("Beat the game in "..canProgress.." !")
		end
		if status.tries == 0 then
			bridge.tweet("Beat Pokemon Red in "..canProgress.."!")
			if strategies.seed then
				print("v"..VERSION..": "..utils.frames().." frames, with seed "..strategies.seed)
				print("Please save this seed number to share, if you would like proof of your run!")
			end
		end
		status.tries = status.tries + 1
	elseif memory.value("menu", "shop_current") == 252 then
		strategies.functions.split({finished=true})
		canProgress = utils.elapsedTime()
	else
		input.cancel()
	end
end

-- PROCESS

function strategies.initGame(midGame)
	if not STREAMING_MODE then
		-- strategies.setYolo("bulbasaur")
		nidoAttack = 55
		nidoSpeed = 50
		nidoSpecial = 45
		riskGiovanni = true
		print(nidoAttack.." x "..nidoSpeed.." "..nidoSpecial)
	end
end

function strategies.resetGame()
	maxEtherSkip = false
	status = strategies.status
end

return strategies
