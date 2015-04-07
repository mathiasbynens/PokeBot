local Strategies = require "ai.strategies"

local Combat = require "ai.combat"
local Control = require "ai.control"

local Battle = require "action.battle"
local Shop = require "action.shop"
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

local level4Nidoran = true -- 57 vs 96 (d39)
local nidoAttack, nidoSpeed, nidoSpecial = 0, 0, 0
local squirtleAtt, squirtleDef, squirtleSpd, squirtleScl
local riskGiovanni, maxEtherSkip

local status = Strategies.status

-- TIME CONSTRAINTS

Strategies.timeRequirements = {

	bulbasaur = function()
		return 2.25
	end,

	nidoran = function()
		local timeLimit = 6.33
		if Pokemon.inParty("spearow") then
			timeLimit = timeLimit + 0.67
		end
		return timeLimit
	end,

	brock = function()
		return 11
	end,

	mt_moon = function()
		local timeLimit = 27
		if nidoAttack > 15 and nidoSpeed > 14 then
			timeLimit = timeLimit + 0.25
		end
		if Pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	mankey = function()
		local timeLimit = 32.5
		if Pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	goldeen = function()
		local timeLimit = 37.5
		if Pokemon.inParty("paras") then
			timeLimit = timeLimit + 0.75
		end
		return timeLimit
	end,

	misty = function()
		local timeLimit = 39.5
		if Pokemon.inParty("paras") then
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
	local sx, sy = Player.position()
	if not disabled and status.tries == nil then
		local opponentName = Battle.opponent()
		local opLevel = Memory.value("battle", "opponent_level")
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
		if status.tries[status.tries.idx] == 0 then
			status.tries.idx = status.tries.idx + 1
			if status.tries.idx > 3 then
				status.tries = 0
			end
			return nidoranDSum()
		end
		if status.tries.x ~= sx or status.tries.y ~= sy then
			status.tries[status.tries.idx] = status.tries[status.tries.idx] - 1
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
	Walk.step(sx, sy)
end

-- STRATEGIES

local strategyFunctions = Strategies.functions

-- General

strategyFunctions.tweetMisty = function()
	if not Strategies.setYolo("misty") then
		local timeLimit = Strategies.getTimeRequirement("misty")
		if not Strategies.overMinute(timeLimit - 0.5) then
			local pbn = ""
			if not Strategies.overMinute(timeLimit - 1) then
				pbn = " (PB pace)"
			end
			local elt = Utils.elapsedTime()
			Strategies.tweetProgress("Got a run going, just beat Misty "..elt.." in"..pbn)
		end
	end
	return true
end

strategyFunctions.tweetVictoryRoad = function()
	local elt = Utils.elapsedTime()
	local pbn = ""
	if not Strategies.overMinute(Strategies.getTimeRequirement("victory_road")) then
		pbn = " (PB pace)"
	end
	local elt = Utils.elapsedTime()
	Strategies.tweetProgress("Entering Victory Road at "..elt..pbn.." on our way to the Elite Four")
	return true
end

strategyFunctions.fightXAccuracy = function()
	return Strategies.prepare("x_accuracy")
end

-- Route

strategyFunctions.squirtleIChooseYou = function()
	if Pokemon.inParty("squirtle") then
		Bridge.caught("squirtle")
		return true
	end
	if Player.face("Up") then
		Textbox.name("A")
	end
end

strategyFunctions.fightBulbasaur = function()
	if status.tries < 9000 and Pokemon.index(0, "level") == 6 then
		if status.tries > 200 then
			squirtleAtt = Pokemon.index(0, "attack")
			squirtleDef = Pokemon.index(0, "defense")
			squirtleSpd = Pokemon.index(0, "speed")
			squirtleScl = Pokemon.index(0, "special")
			if squirtleAtt < 11 and squirtleScl < 12 then
				return Strategies.reset("Bad Squirtle - "..squirtleAtt.." attack, "..squirtleScl.." special")
			end
			status.tries = 9001
		else
			status.tries = status.tries + 1
		end
	end
	if Battle.isActive() and Memory.double("battle", "opponent_hp") > 0 and Strategies.resetTime(Strategies.getTimeRequirement("bulbasaur"), "kill Bulbasaur") then
		return true
	end
	return Strategies.buffTo("tail_whip", 6)
end

-- dodgePalletBoy

strategyFunctions.shopViridianPokeballs = function()
	return Shop.transaction{
		buy = {{name="pokeball", index=0, amount=8}}
	}
end

strategyFunctions.catchNidoran = function()
	if not Control.canCatch() then
		return true
	end
	local pokeballs = Inventory.count("pokeball")
	local caught = Memory.value("player", "party_size") - 1
	if pokeballs < 5 - caught * 2 then
		return Strategies.reset("Ran too low on PokeBalls", pokeballs)
	end
	if Battle.isActive() then
		local isNidoran = Pokemon.isOpponent("nidoran")
		if isNidoran and Memory.value("battle", "opponent_level") > 2 then
			if Strategies.initialize() then
				Bridge.pollForName()
			end
		end
		status.tries = nil
		if Memory.value("menu", "text_input") == 240 then
			Textbox.name()
		elseif Memory.value("battle", "menu") == 95 then
			if isNidoran then
				Input.press("A")
			else
				Input.cancel()
			end
		else
			Battle.handle()
		end
	else
		local noDSum
		Pokemon.updateParty()
		local hasNidoran = Pokemon.inParty("nidoran")
		if hasNidoran then
			local gotExperience = Pokemon.getExp() > 205
			if not status.canProgress then
				Bridge.caught("nidoran")
				status.canProgress = true
				if not gotExperience then
					Bridge.chat("Waiting in the grass for a suitable ecounter to get experience", Pokemon.getExp())
				end
			end
			if gotExperience then
				level4Nidoran = Pokemon.info("nidoran", "level") == 4
				return true
			end
			noDSum = true
		end

		local timeLimit = Strategies.getTimeRequirement("nidoran")
		local resetMessage
		if hasNidoran then
			resetMessage = "get an experience kill before Brock"
		else
			resetMessage = "find a suitable Nidoran"
		end
		if Strategies.resetTime(timeLimit, resetMessage) then
			return true
		end
		if not noDSum and Strategies.overMinute(timeLimit - 0.25) then
			noDSum = true
		end
		nidoranDSum(noDSum)
	end
end

-- 1: NIDORAN

strategyFunctions.dodgeViridianOldMan = function()
	return Strategies.dodgeUp(0x0273, 18, 6, 17, 9)
end

strategyFunctions.grabTreePotion = function()
	if Strategies.initialize() then
		if Pokemon.info("squirtle", "hp") > 15 or Pokemon.info("spearow", "level") == 3 then
			return true
		end
	end
	if Inventory.contains("potion") then
		return true
	end

	local px, py = Player.position()
	if px > 15 then
		Walk.step(15, 4)
	else
		Player.interact("Left")
	end
end

strategyFunctions.grabAntidote = function()
	local px, py = Player.position()
	if py < 11 then
		return true
	end
	if Pokemon.info("spearow", "level") == 3 then
		if px < 26 then
			px = 26
		else
			py = 10
		end
	elseif Inventory.contains("antidote") then
		py = 10
	else
		Player.interact("Up")
	end
	Walk.step(px, py)
end

strategyFunctions.grabForestPotion = function()
	if Battle.handleWild() then
		local potionCount = Inventory.count("potion")
		if Strategies.initialize() then
			status.tries = potionCount
		end
		if potionCount > 0 then
			if status.tries and potionCount > status.tries then
				status.tries = nil
			end
			local healthNeeded = (Pokemon.info("spearow", "level") == 3) and 8 or 15
			if Pokemon.info("squirtle", "hp") <= healthNeeded then
				if Menu.pause() then
					Inventory.use("potion", "squirtle")
				end
			else
				return true
			end
		elseif not status.tries then
			return true
		elseif Menu.close() then
			Player.interact("Up")
		end
	end
end

strategyFunctions.fightWeedle = function()
	if Battle.isTrainer() then
		status.canProgress = true
		local squirtleOut = Pokemon.isDeployed("squirtle")
		if squirtleOut and Memory.value("battle", "our_status") > 0 and not Inventory.contains("antidote") then
			return Strategies.reset("Poisoned, but we skipped the antidote")
		end
		local sidx = Pokemon.indexOf("spearow")
		if sidx ~= -1 and Pokemon.index(sidx, "level") > 3 then
			sidx = -1
		end
		if sidx == -1 then
			return Strategies.buffTo("tail_whip", 5)
		end
		if Pokemon.index(sidx, "hp") < 1 then
			local battleMenu = Memory.value("battle", "menu")
			if Utils.onPokemonSelect(battleMenu) then
				Menu.select(Pokemon.indexOf("squirtle"), true)
			elseif battleMenu == 95 then
				Input.press("A")
			elseif squirtleOut then
				Battle.automate()
			else
				Input.cancel()
			end
		elseif squirtleOut then
			Battle.swap("spearow")
		else
			local peck = Combat.bestMove()
			local forced
			if peck and peck.damage and peck.damage + 1 >= Memory.double("battle", "opponent_hp") then
				forced = "growl"
			end
			Battle.fight(forced)
		end
	elseif status.canProgress then
		return true
	end
end

strategyFunctions.equipForBrock = function(data)
	if Strategies.initialize() then
		if Pokemon.info("squirtle", "level") < 8 then
			local message, wait
			if Pokemon.info("spearow", "level") == 3 then
				message = "Lost too much exp accidentally killing Weedle with Spearow"
			else
				message = "Did not reach level 8 before Brock"
				wait = true
			end
			return Strategies.reset(message, Pokemon.getExp(), wait)
		end
		if data.anti then
			local poisoned = Pokemon.info("squirtle", "status") > 0
			if not poisoned then
				return true
			end
			if not Inventory.contains("antidote") then
				return Strategies.reset("Poisoned, but we risked skipping the antidote")
			end
			local curr_hp = Pokemon.info("squirtle", "hp")
			if Inventory.contains("potion") and curr_hp > 8 and curr_hp < 18 then
				return true
			end
		end
	end
	return strategyFunctions.swapNidoran()
end

strategyFunctions.fightBrock = function()
	local squirtleHP = Pokemon.info("squirtle", "hp")
	if squirtleHP == 0 then
		return Strategies.death()
	end
	if Battle.isActive() then
		if status.tries < 1 then
			status.tries = 1
		end
		local bubble, turnsToKill, turnsToDie = Combat.bestMove()
		if not Pokemon.isDeployed("squirtle") then
			Battle.swap("squirtle")
		elseif turnsToDie and turnsToDie < 2 and Inventory.contains("potion") then
			Inventory.use("potion", "squirtle", true)
		else
			local battleMenu = Memory.value("battle", "menu")
			local bideTurns = Memory.value("battle", "opponent_bide")
			if battleMenu == 95 and Menu.getCol() == 1 then
				Input.press("A")
			elseif bideTurns > 0 then
				local onixHP = Memory.double("battle", "opponent_hp")
				if not status.canProgress then
					status.canProgress = onixHP
					status.tempDir = bideTurns
				end
				if turnsToKill then
					local forced
					if turnsToDie < 2 or turnsToKill < 2 or status.tempDir - bideTurns > 1 then
					-- elseif turnsToKill < 3 and status.tempDir == bideTurns then
					elseif onixHP == status.canProgress then
						forced = "tail_whip"
					end
					Battle.fight(forced)
				else
					Input.cancel()
				end
			elseif Utils.onPokemonSelect(battleMenu) then
				Menu.select(Pokemon.indexOf("nidoran"), true)
			else
				status.canProgress = false
				Battle.fight()
			end
			if status.tries < 9000 then
				local nidx = Pokemon.indexOf("nidoran")
				if Pokemon.index(nidx, "level") == 8 then
					local att = Pokemon.index(nidx, "attack")
					local def = Pokemon.index(nidx, "defense")
					local spd = Pokemon.index(nidx, "speed")
					local scl = Pokemon.index(nidx, "special")
					Bridge.stats(att.." "..def.." "..spd.." "..scl)
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
							return Strategies.reset("Bad Nidoran - "..nStatus)
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
						Bridge.chat(nStatus)
					else
						status.tries = status.tries + 1
					end
				end
			end
		end
	elseif status.tries > 0 then
		return true
	elseif Textbox.handle() then
		Player.interact("Up")
	end
end

-- 2: BROCK

strategyFunctions.shopPewterMart = function()
	return Shop.transaction{
		buy = {{name="potion", index=1, amount=9}}
	}
end

strategyFunctions.battleModeSet = function()
	if Memory.value("setting", "battle_style") == 10 then
		if Menu.close() then
			return true
		end
	elseif Menu.pause() then
		local main = Memory.value("menu", "main")
		if main == 128 then
			if Menu.getCol() ~= 11 then
				Input.press("B")
			else
				Menu.select(5, true)
			end
		elseif main == 228 then
			Menu.setOption("battle_style", 8, 10)
		else
			Input.press("B")
		end
	end
end

strategyFunctions.bugCatcher = function()
	if Battle.isActive() then
		status.canProgress = true
		local isWeedle = Pokemon.isOpponent("weedle")
		if isWeedle and not status.tempDir then
			status.tempDir = true
		end
		secondCaterpie = status.tempDir
		if not isWeedle and secondCaterpie then
			if level4Nidoran and nidoSpeed >= 14 and Pokemon.index(0, "attack") >= 19 then
				-- print("IA "..Pokemon.index(0, "attack"))
				Battle.automate()
				return
			end
		end
		Strategies.functions.leer({{"caterpie",8}, {"weedle",7}})
	elseif status.canProgress then
		return true
	else
		Battle.automate()
	end
end

strategyFunctions.shortsKid = function()
	local fightingEkans = Pokemon.isOpponent("ekans")
	if fightingEkans then
		local wrapping = Memory.value("battle", "turns") > 0
		if wrapping then
			local curr_hp = Memory.double("battle", "our_hp")
			if not status.tempDir then
				status.tempDir = curr_hp
			end
			local wrapDamage = status.tempDir - curr_hp
			if wrapDamage > 0 and wrapDamage < 7 and curr_hp < 14 and not Strategies.opponentDamaged() then
				Inventory.use("potion", nil, true)
				return false
			end
		elseif status.tempDir then
			status.tempDir = nil
		end
	end
	Control.battlePotion(fightingEkans or Strategies.damaged(2))
	return Strategies.functions.leer({{"rattata",9}, {"ekans",10}})
end

strategyFunctions.potionBeforeCocoons = function()
	if nidoSpeed >= 15 then
		return true
	end
	return Strategies.functions.potion({hp=6, yolo=3})
end

-- swapHornAttack

strategyFunctions.fightMetapod = function()
	if Battle.isActive() then
		status.canProgress = true
		if Memory.double("battle", "opponent_hp") > 0 and Pokemon.isOpponent("metapod") then
			return true
		end
		Battle.automate()
	elseif status.canProgress then
		return true
	else
		Battle.automate()
	end
end

-- catchFlierBackup

-- 3: ROUTE 3

-- startMtMoon

-- evolveNidorino

-- evolveNidoking

-- helix

-- reportMtMoon

-- 4: MT. MOON

-- dodgeCerulean

-- dodgeCeruleanLeft

strategyFunctions.rivalSandAttack = function(data)
	if Battle.isActive() then
		if Battle.redeployNidoking() then
			return false
		end
		local opponent = Battle.opponent()
		if Memory.value("battle", "accuracy") < 7 then
			local sacrifice
			if opponent == "pidgeotto" then
				local __, turns = Combat.bestMove()
				if turns == 1 then
					sacrifice = Pokemon.getSacrifice("pidgey", "spearow", "paras", "oddish", "squirtle")
				end
			elseif opponent == "raticate" then
				sacrifice = Pokemon.getSacrifice("pidgey", "spearow", "oddish")
			end
			if Battle.sacrifice(sacrifice) then
				return false
			end
		end

		if opponent == "pidgeotto" then
			Combat.disableThrash = true
		elseif opponent == "raticate" then
			Combat.disableThrash = Strategies.opponentDamaged() or (not Control.yolo and Pokemon.index(0, "hp") < 32) -- RISK
		elseif opponent == "ivysaur" then
			if not Control.yolo and Strategies.damaged(5) and Inventory.contains("super_potion") then
				Inventory.use("super_potion", nil, true)
				return false
			end
			Combat.disableThrash = Strategies.opponentDamaged()
		else
			Combat.disableThrash = false
		end
		Battle.automate()
		status.canProgress = true
	elseif status.canProgress then
		Combat.disableThrash = false
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.teachThrash = function()
	if Strategies.initialize() then
		if Pokemon.hasMove("thrash") or Pokemon.info("nidoking", "level") < 21 then
			return true
		end
	end
	if Strategies.functions.teach({move="thrash",item="rare_candy",replace="leer"}) then
		if Menu.close() then
			local att = Pokemon.index(0, "attack")
			local def = Pokemon.index(0, "defense")
			local spd = Pokemon.index(0, "speed")
			local scl = Pokemon.index(0, "special")
			local statDesc = att.." "..def.." "..spd.." "..scl
			nidoAttack = att
			nidoSpeed = spd
			nidoSpecial = scl
			Bridge.stats(statDesc)
			print(statDesc)
			return true
		end
	end
end

strategyFunctions.potionForMankey = function()
	if Strategies.initialize() then
		if Pokemon.info("nidoking", "level") > 20 then
			return true
		end
	end
	return Strategies.functions.potion({hp=18, yolo=8})
end

strategyFunctions.redbarMankey = function()
	if not Strategies.setYolo("mankey") then
		return true
	end
	local curr_hp, red_hp = Pokemon.index(0, "hp"), Combat.redHP()
	if curr_hp <= red_hp then
		return true
	end
	if Strategies.initialize() then
		if Pokemon.info("nidoking", "level") < 23 or Inventory.count("potion") < 3 then -- RISK
			return true
		end
		Bridge.chat("Using Poison Sting to attempt to red-bar off Mankey")
	end
	if Battle.isActive() then
		status.canProgress = true
		local enemyMove, enemyTurns = Combat.enemyAttack()
		if enemyTurns then
			if enemyTurns < 2 then
				return true
			end
			local scratchDmg = enemyMove.damage
			if curr_hp - scratchDmg >= red_hp then
				return true
			end
		end
		Battle.automate("poison_sting")
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.thrashGeodude = function()
	if Battle.isActive() then
		status.canProgress = true
		if Pokemon.isOpponent("geodude") and Pokemon.isDeployed("nidoking") then
			if Battle.sacrifice("squirtle") then
				return false
			end
		end
		Battle.automate()
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.potionBeforeGoldeen = function()
	if Strategies.initialize() then
		if Strategies.setYolo("goldeen") or Pokemon.index(0, "hp") > 7 then
			return true
		end
	end
	return Strategies.functions.potion({hp=64, chain=true})
end

strategyFunctions.potionBeforeMisty = function()
	local healAmount = 70
	if Control.yolo then
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
	if Strategies.initialize() then
		local message
		local potionCount = Inventory.count("potion")
		local needsToHeal = healAmount - Pokemon.index(0, "hp")
		if potionCount * 20 < needsToHeal then
			message = "Ran too low on potions to heal enough before Misty"
		elseif healAmount < 60 then
			message = "Limiting heals to attempt to get closer to red-bar off Misty"
		end
		if message then
			Bridge.chat(message, potionCount)
		end
	end
	return Strategies.functions.potion({hp=healAmount})
end

strategyFunctions.fightMisty = function()
	if Battle.isActive() then
		status.canProgress = true
		if Battle.redeployNidoking() then
			if status.tempDir == false then
				status.tempDir = true
			end
			return false
		end
		local swappedOut = status.tempDir
		if not swappedOut and Combat.isConfused() then
			status.tempDir = false
			if Battle.sacrifice("pidgey", "spearow", "paras") then
				return false
			end
		end
		Battle.automate()
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

-- 6: MISTY

strategyFunctions.potionBeforeRocket = function()
	local minAttack = 55 -- RISK
	if Control.yolo then
		minAttack = minAttack - 1
	end
	if nidoAttack >= minAttack then
		return true
	end
	return Strategies.functions.potion({hp=10})
end

strategyFunctions.jingleSkip = function()
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
end

strategyFunctions.catchOddish = function()
	if not Control.canCatch() then
		return true
	end
	local caught = Pokemon.inParty("oddish", "paras")
	local battleValue = Memory.value("game", "battle")
	local px, py = Player.position()
	if battleValue > 0 then
		if battleValue == 2 then
			status.tries = 2
			Battle.automate()
		else
			if status.tries == 0 and py == 31 then
				status.tries = 1
			end
			Battle.handle()
		end
	elseif status.tries == 1 and py == 31 then
		Player.interact("Left")
	else
		local path
		if caught then
			if not status.tempDir then
				Bridge.caught(Pokemon.inParty("oddish"))
				status.tempDir = true
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
			Walk.step(px, py)
		elseif px == 12 then
			local dy
			if py == 30 then
				dy = 31
			else
				dy = 30
			end
			Walk.step(px, dy)
		else
			local path = {{15,19}, {15,25}, {15,25}, {15,27}, {14,27}, {14,30}, {12,30}}
			Walk.custom(path)
		end
	end
end

strategyFunctions.shopVermilionMart = function()
	if Strategies.initialize() then
		Strategies.setYolo("vermilion")
	end
	local buyArray, sellArray
	if not Inventory.contains("pokeball") or (not Control.yolo and nidoAttack < 53) then
		sellArray = {{name="pokeball"}, {name="antidote"}, {name="tm34"}, {name="nugget"}}
		buyArray = {{name="super_potion",index=1,amount=3}, {name="paralyze_heal",index=4,amount=2}, {name="repel",index=5,amount=3}}
	else
		sellArray = {{name="antidote"}, {name="tm34"}, {name="nugget"}}
		buyArray = {{name="super_potion",index=1,amount=3}, {name="repel",index=5,amount=3}}
	end
	return Shop.transaction {
		sell = sellArray,
		buy = buyArray
	}
end

-- rivalSandAttack

strategyFunctions.trashcans = function()
	local progress = Memory.value("progress", "trashcans")
	if Textbox.isActive() then
		if not status.canProgress then
			if progress < 2 then
				status.tries = status.tries + 1
			end
			status.canProgress = true
		end
		Input.cancel()
	else
		if progress == 3 then
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
				Bridge.chat(prefix..", "..status.tries.." try Trashcans"..suffix, Utils.elapsedTime())
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
			Input.press(walkIn, 0)
		elseif progress == 2 then
			if status.canProgress then
				status.canProgress = false
				Walk.invertCustom()
			end
			local inverse = {
				Up = "Down",
				Right = "Left",
				Down = "Up",
				Left = "Right"
			}
			Player.interact(inverse[status.tempDir])
		else
			local trashPath = {{2,11},{"Left"},{2,11}, {2,12},{4,12},{4,11},{"Right"},{4,11}, {4,9},{"Left"},{4,9}, {4,7},{"Right"},{4,7}, {4,6},{2,6},{2,7},{"Left"},{2,7}, {2,6},{4,6},{4,8},{9,8},{"Up"},{9,8}, {8,8},{8,9},{"Left"},{8,9}, {8,10},{9,10},{"Down"},{9,10},{8,10}}
			if status.tempDir and type(status.tempDir) == "number" then
				local px, py = Player.position()
				local dx, dy = px, py
				if py < 12 then
					dy = 12
				elseif status.tempDir == 1 then
					dx = 2
				else
					dx = 8
				end
				if px ~= dx or py ~= dy then
					Walk.step(dx, dy)
					return
				end
				status.tempDir = nil
			end
			status.tempDir = Walk.custom(trashPath, status.canProgress)
			status.canProgress = false
		end
	end
end

strategyFunctions.fightSurge = function()
	if Battle.isActive() then
		status.canProgress = true
		local forced
		if Pokemon.isOpponent("voltorb") then
			Combat.disableThrash = true
			local __, enemyTurns = Combat.enemyAttack()
			if not enemyTurns or enemyTurns > 2 then
				forced = "bubblebeam"
			elseif enemyTurns == 2 and not Strategies.opponentDamaged() then
				local curr_hp, red_hp = Pokemon.index(0, "hp"), Combat.redHP()
				local afterHit = curr_hp - 20
				if afterHit > 5 and afterHit <= red_hp then
					forced = "bubblebeam"
				end
			end
		else
			Combat.disableThrash = false
		end
		Battle.automate(forced)
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

-- 7: SURGE

strategyFunctions.procureBicycle = function()
	if Inventory.contains("bicycle") then
		if not Textbox.isActive() then
			return true
		end
		Input.cancel()
	elseif Textbox.handle() then
		Player.interact("Right")
	end
end

strategyFunctions.swapBicycle = function()
	local bicycleIdx = Inventory.indexOf("bicycle")
	if bicycleIdx < 3 then
		return true
	end
	local main = Memory.value("menu", "main")
	if main == 128 then
		if Menu.getCol() ~= 5 then
			Menu.select(2, true)
		else
			local selection = Memory.value("menu", "selection_mode")
			if selection == 0 then
				if Menu.select(0, "accelerate", true, nil, true) then
					Input.press("Select")
				end
			else
				if Menu.select(bicycleIdx, "accelerate", true, nil, true) then
					Input.press("Select")
				end
			end
		end
	else
		Menu.pause()
	end
end

strategyFunctions.redbarCubone = function()
	if Battle.isActive() then
		local forced
		status.canProgress = true
		if Pokemon.isOpponent("cubone") then
			local enemyMove, enemyTurns = Combat.enemyAttack()
			if enemyTurns then
				local curr_hp, red_hp = Pokemon.index(0, "hp"), Combat.redHP()
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
				if forced and Strategies.initialize() then
					Bridge.chat("Using Thunderbolt to attempt to redbar off Cubone")
				end
			end
		end
		Battle.automate(forced)
	elseif status.canProgress then
		return true
	else
		Battle.automate()
	end
end

strategyFunctions.shopTM07 = function()
	return Shop.transaction{
		direction = "Up",
		buy = {{name="horn_drill", index=3}}
	}
end

strategyFunctions.shopRepels = function()
	return Shop.transaction{
		direction = "Up",
		buy = {{name="super_repel", index=3, amount=9}}
	}
end

strategyFunctions.shopPokeDoll = function()
	return Shop.transaction{
		direction = "Down",
		buy = {{name="pokedoll", index=0}}
	}
end

strategyFunctions.shopVending = function()
	return Shop.vend{
		direction = "Up",
		buy = {{name="fresh_water", index=0}, {name="soda_pop", index=1}}
	}
end

strategyFunctions.giveWater = function()
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
end

strategyFunctions.shopExtraWater = function()
	return Shop.vend{
		direction = "Up",
		buy = {{name="fresh_water", index=0}}
	}
end

strategyFunctions.shopBuffs = function()
	if Strategies.initialize() then
		local minSpecial = 45
		if Control.yolo then
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
	return Shop.transaction{
		direction = "Up",
		buy = {{name="x_accuracy", index=0, amount=10}, {name="x_speed", index=5, amount=4}, {name="x_special", index=6, amount=xspecAmt}}
	}
end

strategyFunctions.deptElevator = function()
	if Textbox.isActive() then
		status.canProgress = true
		Menu.select(0, false)
	else
		if status.canProgress then
			return true
		end
		Player.interact("Up")
	end
end

strategyFunctions.swapRepels = function()
	local repelIdx = Inventory.indexOf("super_repel")
	if repelIdx < 3 then
		return true
	end
	local main = Memory.value("menu", "main")
	if main == 128 then
		if Menu.getCol() ~= 5 then
			Menu.select(2, true)
		else
			local selection = Memory.value("menu", "selection_mode")
			if selection == 0 then
				if Menu.select(1, "accelerate", true, nil, true) then
					Input.press("Select")
				end
			else
				if Menu.select(repelIdx, "accelerate", true, nil, true) then
					Input.press("Select")
				end
			end
		end
	else
		Menu.pause()
	end
end

-- 8: FLY

strategyFunctions.lavenderRival = function()
	if Battle.isActive() then
		status.canProgress = true
		local forced
		if nidoSpecial > 44 then -- RISK
			local __, enemyTurns = Combat.enemyAttack()
			if enemyTurns and enemyTurns < 2 and Pokemon.isOpponent("pidgeotto", "gyarados") then
				Battle.automate()
				return false
			end
		end
		if Pokemon.isOpponent("gyarados") or Strategies.prepare("x_accuracy") then
			Battle.automate()
		end
	elseif status.canProgress then
		return true
	else
		Input.cancel()
	end
end

strategyFunctions.digFight = function()
	if Battle.isActive() then
		status.canProgress = true
		local currentlyDead = Memory.double("battle", "our_hp") == 0
		if currentlyDead then
			local backupPokemon = Pokemon.getSacrifice("paras", "squirtle")
			if not backupPokemon then
				return Strategies.death()
			end
			if Utils.onPokemonSelect(Memory.value("battle", "menu")) then
				Menu.select(Pokemon.indexOf(backupPokemon), true)
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
end

strategyFunctions.pokeDoll = function()
	if Battle.isActive() then
		status.canProgress = true
		Inventory.use("pokedoll", nil, true)
	elseif status.canProgress then
		return true
	else
		Input.cancel()
	end
end

strategyFunctions.thunderboltFirst = function()
	local forced
	if Pokemon.isOpponent("zubat") then
		status.canProgress = true
		forced = "thunderbolt"
	elseif status.canProgress then
		return true
	end
	Battle.automate(forced)
end

-- 8: POKÉFLUTE

-- playPokeflute

strategyFunctions.drivebyRareCandy = function()
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
end

strategyFunctions.safariCarbos = function()
	if Strategies.initialize() then
		Strategies.setYolo("safari_carbos")
	end
	local minSpeed = 50
	if Control.yolo then
		minSpeed = minSpeed - 1
	end
	if nidoSpeed >= minSpeed then
		return true
	end
	if Inventory.contains("carbos") then
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
end

strategyFunctions.centerSkipFullRestore = function()
	if Strategies.initialize() then
		if Control.yolo or Inventory.contains("full_restore") then
			return true
		end
		Bridge.chat("We need to grab the backup Full Restore here.")
	end
	local px, py = Player.position()
	if px < 21 then
		px = 21
	elseif py < 9 then
		py = 9
	else
		return Strategies.functions.interact({dir="Down"})
	end
	Walk.step(px, py)
end

strategyFunctions.silphElevator = function()
	if Textbox.isActive() then
		status.canProgress = true
		Menu.select(9, false, true)
	else
		if status.canProgress then
			return true
		end
		Player.interact("Up")
	end
end

strategyFunctions.fightSilphMachoke = function()
	if Battle.isActive() then
		status.canProgress = true
		if nidoSpecial > 44 then
			return Strategies.prepare("x_accuracy")
		end
		Battle.automate("thrash")
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.silphCarbos = function()
	if nidoSpeed > 50 then
		return true
	end
	return Strategies.functions.interact({dir="Left"})
end

strategyFunctions.silphRival = function()
	if Battle.isActive() then
		if Strategies.initialize() then
			status.tempDir = Combat.healthFor("RivalGyarados")
			status.canProgress = true
		end
		local gyaradosDamage = status.tempDir

		local forced
		local readyToAttack = false
		local opponentName = Battle.opponent()
		if opponentName == "gyarados" then
			readyToAttack = true
			local hp, red_hp = Pokemon.index(0, "hp"), Combat.redHP()
			if hp > gyaradosDamage * 0.98 and hp - gyaradosDamage * 0.975 < red_hp then --TODO
				if Strategies.prepare("x_special") then
					forced = "ice_beam"
				else
					readyToAttack = false
				end
			elseif Strategies.isPrepared("x_special") then
				local canPotion
				if Inventory.contains("potion") and hp + 20 > gyaradosDamage and hp + 20 - gyaradosDamage < red_hp then
					canPotion = "potion"
				elseif Inventory.contains("super_potion") and hp + 50 > gyaradosDamage and hp + 50 - gyaradosDamage < red_hp then
					canPotion = "super_potion"
				end
				if canPotion then
					Inventory.use(canPotion, nil, true)
					readyToAttack = false
				end
			end
		elseif Strategies.prepare("x_accuracy", "x_speed") then
			if opName == "pidgeot" then
				if nidoSpecial < 45 or Strategies.hasHealthFor("KogaWeezing", 10) then --TODO remove for red bar
					forced = "thunderbolt"
				end
			elseif opponentName == "alakazam" or opponentName == "growlithe" then
				forced = "earthquake"
			end
			readyToAttack = true
		end
		if readyToAttack then
			Battle.automate(forced)
		end
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.potionBeforeGiovanni = function()
	-- TODO verify newly leveled
	-- local curr_hp = Pokemon.index(0, "hp")
	-- if curr_hp < 16 and Pokemon.index(0, "level") == 37 then
	-- 	local rareCandyCount = Inventory.count("rare_candy")
	-- 	if rareCandyCount > 2 then
	-- 		if Menu.pause() then
	-- 			Inventory.use("rare_candy", nil, false)
	-- 		end
	-- 		return false
	-- 	end
	-- end
	return Strategies.functions.potion({hp=16, yolo=12, close=true})
end

strategyFunctions.fightSilphGiovanni = function()
	if Battle.isActive() then
		status.canProgress = true
		local forced
		local opponentName = Battle.opponent()
		if opponentName == "nidorino" then
			if Battle.pp("horn_drill") > 2 then
				forced = "horn_drill"
			else
				forced = "earthquake"
			end
		elseif opponentName == "rhyhorn" then
			forced = "ice_beam"
		elseif opponentName == "kangaskhan" or opponentName == "nidoqueen" then
			forced = "horn_drill"
		end
		Battle.automate(forced)
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

--	9: SILPH CO.

strategyFunctions.potionBeforeHypno = function()
	local curr_hp, red_hp = Pokemon.index(0, "hp"), Combat.redHP()
	local healthUnderRedBar = red_hp - curr_hp
	local yoloHP = Combat.healthFor("HypnoHeadbutt") * 0.9
	local useRareCandy = Inventory.count("rare_candy") > 2

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
			-- useRareCandy = curr_hp < Combat.healthFor("KogaWeezing") * 0.85
		end
	end
	if useRareCandy then
		if Menu.pause() then
			Inventory.use("rare_candy", nil, false)
		end
		return false
	end

	return Strategies.functions.potion({hp=healTarget, yolo=yoloHP, close=true})
end

strategyFunctions.fightHypno = function()
	if Battle.isActive() then
		local forced
		if Pokemon.isOpponent("hypno") then
			if Pokemon.info("nidoking", "hp") > Combat.healthFor("KogaWeezing") * 0.9 then
				if Combat.isDisabled(85) then
					forced = "ice_beam"
				else
					forced = "thunderbolt"
				end
			end
		end
		Battle.automate(forced)
		status.canProgress = true
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.fightKoga = function() --TODO x-accuracy?
	if Battle.isActive() then
		local forced
		if Pokemon.isOpponent("weezing") then
			if Strategies.opponentDamaged(2) then
				Inventory.use("pokeflute", nil, true)
				return false
			end
			if Combat.isDisabled(85) then
				forced = "ice_beam"
			else
				forced = "thunderbolt"
			end
			Control.canDie(true)
		end
		Battle.automate(forced)
		status.canProgress = true
	elseif status.canProgress then
		Strategies.deepRun = true
		return true
	else
		Textbox.handle()
	end
end

-- 10: KOGA

strategyFunctions.dodgeGirl = function()
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
end

strategyFunctions.cinnabarCarbos = function()
	local px, py = Player.position()
	if px == 21 then
		return true
	end
	local minSpeed = 51
	if Control.yolo then
		minSpeed = minSpeed - 1
	end
	if nidoSpeed > minSpeed then -- TODO >=
		Walk.step(21, 20)
	else
		if py == 20 then
			py = 21
		elseif px == 17 and not Inventory.contains("carbos") then
			Player.interact("Right")
			return false
		else
			px = 21
		end
		Walk.step(px, py)
	end
end

strategyFunctions.fightErika = function()
	if Battle.isActive() then
		status.canProgress = true
		local forced
		local curr_hp, red_hp = Pokemon.index(0, "hp"), Combat.redHP()
		local razorDamage = 34
		if curr_hp > razorDamage and curr_hp - razorDamage < red_hp then
			if Strategies.opponentDamaged() then
				forced = "thunderbolt"
			elseif nidoSpecial < 45 then
				forced = "ice_beam"
			else
				forced = "thunderbolt"
			end
		elseif riskGiovanni then
			forced = "ice_beam"
		end
		Battle.automate(forced)
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

-- 11: ERIKA

strategyFunctions.waitToReceive = function()
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
end

-- 14: SABRINA

strategyFunctions.earthquakeElixer = function(data)
	if Battle.pp("earthquake") >= data.min then
		if Strategies.closeMenuFor(data) then
			return true
		end
		return false
	end
	if Strategies.initialize() then
		print("EQ Elixer: "..Control.areaName)
	end
	return Strategies.useItem({item="elixer", poke="nidoking", chain=data.chain, close=data.close})
end

strategyFunctions.fightGiovanniMachoke = function()
	if Strategies.initialize() then
		if nidoAttack >= 55 then
			local eqPpRequired = nidoSpecial >= 47 and 7 or 8
			if Battle.pp("earthquake") >= eqPpRequired then
				Bridge.chat("Using Earthquake strats on the Machokes")
				return true
			end
		end
	end
	return Strategies.prepare("x_special")
end

strategyFunctions.checkGiovanni = function()
	local ryhornDamage = math.floor(Combat.healthFor("GiovanniRhyhorn") * 0.95) --RISK
	if Strategies.initialize() then
		local earthquakePP = Battle.pp("earthquake")
		if earthquakePP >= 2 then
			if riskGiovanni then
				if earthquakePP >= 5 then
					Bridge.chat("Saved enough Earthquake PP for safe strats on Giovanni")
				elseif earthquakePP >= 3 and Battle.pp("horn_drill") >= 5 and (Control.yolo or Pokemon.info("nidoking", "hp") >= ryhornDamage) then -- RISK
					Bridge.chat("Using risky strats on Giovanni to skip the extra Max Ether...")
				else
					riskGiovanni = false
				end
			end
			return true
		end
		local message = "Ran out of Earthquake PP :( "
		if Control.yolo then
			message = message.."Risking on Giovanni."
		else
			message = message.."Time for standard strats."
		end
		Bridge.chat(message)
		riskGiovanni = false
	end
	return Strategies.functions.potion({hp=50, yolo=ryhornDamage})
end

strategyFunctions.fightGiovanni = function()
	if Battle.isActive() then
		if Strategies.initialize() then
			status.tempDir = Battle.pp("earthquake")
			status.canProgress = true
		end
		local forced, needsXSpecial
		local startEqPP = status.tempDir
		if riskGiovanni then
			if startEqPP < 5 then
				needsXSpecial = true
			end
			if needsXSpecial or Battle.pp("earthquake") < 4 then
				forced = "ice_beam"
			end
		else
			needsXSpecial = startEqPP < 2
			if Pokemon.isOpponent("rhydon") then
				forced = "ice_beam"
			end
		end
		if needsXSpecial and not Strategies.prepare("x_special") then
			return false
		end
		Battle.automate(forced)
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

-- 15: GIOVANNI

strategyFunctions.viridianRival = function()
	if Battle.isActive() then
		if not status.canProgress then
			if riskGiovanni or nidoSpecial < 45 or Pokemon.index(0, "speed") < 134 then
				status.tempDir = "x_special"
			else
				print("Skip X Special strats!")
			end
			status.canProgress = true
		end
		if Strategies.prepare("x_accuracy", status.tempDir) then
			local forced
			if Pokemon.isOpponent("pidgeot") then
				forced = "thunderbolt"
			elseif riskGiovanni then
				if Pokemon.isOpponent("rhyhorn") or Strategies.opponentDamaged() then
					forced = "ice_beam"
				elseif Pokemon.isOpponent("gyarados") then
					forced = "thunderbolt"
				elseif Pokemon.isOpponent("growlithe", "alakazam") then
					forced = "earthquake"
				end
			end
			Battle.automate(forced)
		end
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.ether = function(data)
	local main = Memory.value("menu", "main")
	data.item = status.tempDir
	if status.tempDir and Strategies.completedMenuFor(data) then
		if Strategies.closeMenuFor(data) then
			return true
		end
	else
		if not status.tempDir then
			if data.max then
				-- TODO don't skip center if not in redbar
				maxEtherSkip = nidoAttack > 53 and Battle.pp("earthquake") > 0 and Battle.pp("horn_drill") > 3
				if maxEtherSkip then
					return true
				end
				Bridge.chat("Grabbing the Max Ether to skip the Elite 4 Center")
			end
			status.tempDir = Inventory.contains("ether", "max_ether")
			if not status.tempDir then
				return true
			end
			status.tries = Inventory.count(status.tempDir) --TODO remove?
		end
		if Memory.value("menu", "main") == 144 and Menu.getCol() == 5 then
			if Memory.value("battle", "menu") ~= 95 then
				Menu.select(Pokemon.battleMove("horn_drill"), true)
			else
				Input.cancel()
			end
		elseif Menu.pause() then
			Inventory.use(status.tempDir, "nidoking")
		end
	end
end

strategyFunctions.pickMaxEther = function()
	if not status.canProgress then
		if maxEtherSkip then
			return true
		end
		if Memory.value("player", "moving") == 0 then
			if Player.isFacing("Right") then
				status.canProgress = true
			end
			status.tempDir = not status.tempDir
			if status.tempDir then
				Input.press("Right", 1)
			end
		end
		return false
	end
	if Inventory.contains("max_ether") then
		return true
	end
	Player.interact("Right")
end

-- push

strategyFunctions.potionBeforeLorelei = function()
	if Strategies.initialize() then
		local canPotion
		if Inventory.contains("potion") and Strategies.hasHealthFor("LoreleiDewgong", 20) then
			canPotion = true
		elseif Inventory.contains("super_potion") and Strategies.hasHealthFor("LoreleiDewgong", 50) then
			canPotion = true
		end
		if not canPotion then
			return true
		end
		Bridge.chat("Healing before Lorelei to skip the Elite 4 Center...")
	end
	return Strategies.functions.potion({hp=Combat.healthFor("LoreleiDewgong")})
end

strategyFunctions.depositPokemon = function()
	local toSize
	if Strategies.hasHealthFor("LoreleiDewgong") then
		toSize = 1
	else
		toSize = 2
	end
	if Memory.value("player", "party_size") == toSize then
		if Menu.close() then
			return true
		end
	else
		if not Textbox.isActive() then
			Player.interact("Up")
		else
			local pc = Memory.value("menu", "size")
			if Memory.value("battle", "menu") ~= 95 and (pc == 2 or pc == 4) then
				local menuColumn = Menu.getCol()
				if menuColumn == 10 then
					Input.press("A")
				elseif menuColumn == 5 then
					local depositIndex = 1
					local depositAllExtras = toSize == 1
					if not depositAllExtras and Pokemon.indexOf("pidgey", "spearow") == 1 then
						depositIndex = 2
					end
					Menu.select(depositIndex)
				else
					Menu.select(1)
				end
			else
				Input.press("A")
			end
		end
	end
end

strategyFunctions.centerSkip = function()
	Strategies.setYolo("e4center")
	local message = "Skipping the Center and attempting to red-bar "
	if Strategies.hasHealthFor("LoreleiDewgong") then
		message = message.."off Lorelei..."
	else
		message = message.."the Elite 4!"
	end
	Bridge.chat(message)
	return true
end

strategyFunctions.lorelei = function()
	if Battle.isActive() then
		status.canProgress = true
		if Battle.redeployNidoking() then
			return false
		end
		local forced
		local opponentName = Battle.opponent()
		if opponentName == "dewgong" then
			if Battle.sacrifice("pidgey", "spearow", "squirtle", "paras", "oddish") then
				return false
			end
		elseif opponentName == "jinx" then
			if Battle.pp("horn_drill") < 2 then
				forced = "earthquake"
			end
		end
		if Strategies.prepare("x_accuracy") then
			Battle.automate(forced)
		end
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

-- 16: LORELEI

strategyFunctions.bruno = function()
	if Battle.isActive() then
		status.canProgress = true
		local forced
		if Pokemon.isOpponent("onix") then
			forced = "ice_beam"
			-- local curr_hp, red_hp = Pokemon.info("nidoking", "hp"), Combat.redHP()
			-- if curr_hp > red_hp then
			-- 	local enemyMove, enemyTurns = Combat.enemyAttack()
			-- 	if enemyTurns and enemyTurns > 1 then
			-- 		local rockDmg = enemyMove.damage
			-- 		if curr_hp - rockDmg <= red_hp then
			-- 			forced = "thunderbolt"
			-- 		end
			-- 	end
			-- end
		end
		if Strategies.prepare("x_accuracy") then
			Battle.automate(forced)
		end
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.agatha = function() --TODO test without x acc
	if Battle.isActive() then
		status.canProgress = true
		if Combat.isSleeping() then
			Inventory.use("pokeflute", nil, true)
			return false
		end
		if Pokemon.isOpponent("gengar") then
			local currentHP = Pokemon.info("nidoking", "hp")
			if not Control.yolo and currentHP <= 56 and not Strategies.isPrepared("x_speed") then
				local toPotion = Inventory.contains("full_restore", "super_potion")
				if toPotion then
					Inventory.use(toPotion, nil, true)
					return false
				end
			end
			if not Strategies.prepare("x_speed") then
				return false
			end
		end
		Battle.automate()
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.prepareForLance = function()
	local enableFull
	if Strategies.hasHealthFor("LanceGyarados", 100) then
		enableFull = Inventory.count("super_potion") < 2
	elseif Strategies.hasHealthFor("LanceGyarados", 50) then
		enableFull = not Inventory.contains("super_potion")
	else
		enableFull = true
	end
	local min_recovery = Combat.healthFor("LanceGyarados")
	return Strategies.functions.potion({hp=min_recovery, full=enableFull, chain=true})
end

strategyFunctions.lance = function()
	if Battle.isActive() then
		status.canProgress = true
		local xItem
		if Pokemon.isOpponent("dragonair") then
			xItem = "x_speed"
		else
			xItem = "x_special"
		end
		if Strategies.prepare(xItem) then
			Battle.automate()
		end
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.prepareForBlue = function()
	if Strategies.initialize() then
		Strategies.setYolo("blue")
	end
	local skyDmg = Combat.healthFor("BlueSky") * 0.925
	local wingDmg = Combat.healthFor("BluePidgeot")
	return Strategies.functions.potion({hp=skyDmg-50, yolo=wingDmg, full=true})
end

strategyFunctions.blue = function()
	if Battle.isActive() then
		if not status.canProgress then
			status.canProgress = true
			if nidoSpecial >= 45 and Pokemon.index(0, "speed") >= 52 and Inventory.contains("x_special") then
				status.tempDir = "x_special"
			else
				status.tempDir = "x_speed"
			end
			if not STREAMING_MODE then
				status.tempDir = "x_speed"
			end
		end

		local boostFirst = Pokemon.index(0, "hp") < 55
		local firstItem, secondItem
		if boostFirst then
			firstItem = status.tempDir
			secondItem = "x_accuracy"
		else
			firstItem = "x_accuracy"
			secondItem = status.tempDir
		end

		local forced = "horn_drill"

		if Memory.value("battle", "turns") > 0 then
			local skyDamage = Combat.healthFor("BlueSky")
			local healCutoff = skyDamage * 0.825
			if Strategies.initialize() then
				if not Strategies.isPrepared("x_accuracy", status.tempDir) then
					local msg = "Uh oh... First-turn Sky Attack could end the run here, "
					if Pokemon.index(0, "hp") > skyDamage then
						msg = msg.."no criticals pls D:"
					elseif Strategies.canHealFor(healCutoff) then
						msg = msg.."attempting to heal for it"
						if not Strategies.canHealFor(skyDamage) then
							msg = msg.." (damage range)"
						end
						msg = msg.."."
					else
						msg = msg.."and nothing left to heal with BibleThump"
					end
					Bridge.chat(msg)
				end
			end

			if Strategies.prepare(firstItem) then
				if not Strategies.isPrepared(secondItem) then
					local toPotion = Strategies.canHealFor(healCutoff)
					if toPotion then
						Inventory.use(toPotion, nil, true)
						return false
					end
				end
				if Strategies.prepare("x_accuracy", status.tempDir) then
					Battle.automate(forced)
				end
			end
		else
			if Strategies.prepare(firstItem, secondItem) then
				if Pokemon.isOpponent("alakazam") then
					if status.tempDir == "x_speed" then
						forced = "earthquake"
					end
				elseif Pokemon.isOpponent("rhydon") then
					if status.tempDir == "x_special" then
						forced = "ice_beam"
					end
				end
				Battle.automate(forced)
			end
		end
	elseif status.canProgress then
		return true
	else
		Textbox.handle()
	end
end

strategyFunctions.champion = function()
	if status.canProgress then
		if status.tries > 1500 then
			return Strategies.hardReset("Beat the game in "..status.canProgress.." !")
		end
		if status.tries == 0 then
			Strategies.tweetProgress("Beat Pokemon Red in "..status.canProgress.."!", true)
			if Strategies.seed then
				print("v"..VERSION..": "..Utils.frames().." frames, with seed "..Strategies.seed)
				print("Please save this seed number to share, if you would like proof of your run!")
			end
		end
		status.tries = status.tries + 1
	elseif Memory.value("menu", "shop_current") == 252 then
		Strategies.functions.split({finished=true})
		status.canProgress = Utils.elapsedTime()
	else
		Input.cancel()
	end
end

-- PROCESS

function Strategies.initGame(midGame)
	if not STREAMING_MODE then
		-- Strategies.setYolo("bulbasaur")
		nidoAttack = 55
		nidoSpeed = 50
		nidoSpecial = 45
		riskGiovanni = true
		print(nidoAttack.." x "..nidoSpeed.." "..nidoSpecial)
	end
end

function Strategies.completeGameStrategy()
	status = Strategies.status
end

function Strategies.resetGame()
	maxEtherSkip = false
	status = Strategies.status
end

return Strategies
