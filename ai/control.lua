local Control = {}

local Combat = require "ai.combat"
local Strategies

local Bridge = require "util.bridge"
local Memory = require "util.memory"
local Paint = require "util.paint"
local Utils = require "util.utils"

local Inventory = require "storage.inventory"
local Pokemon = require "storage.pokemon"

local potionInBattle = true
local fightEncounter, caveFights = 0, 0
local encounters = 0

local canDie, shouldFight, minExp
local shouldCatch, attackIdx
local extraEncounter, maxEncounters
local battleYolo

local yellow = YELLOW

Control.areaName = "Unknown"
Control.moonEncounters = nil
Control.yolo = false

local function withinOneKill(forExp)
	return Pokemon.getExp() + 80 > forExp
end

local controlFunctions = {

	a = function(data)
		Control.areaName = data.a
		return true
	end,

	potion = function(data)
		if data.b ~= nil then
			Control.battlePotion(data.b)
		end
		battleYolo = data.yolo
	end,

	encounters = function(data)
		if RESET_FOR_TIME then
			maxEncounters = data.limit
			extraEncounter = data.extra
		end
	end,

	pp = function(data)
		Combat.factorPP(data.on)
	end,

	setThrash = function(data)
		Combat.disableThrash = data.disable
	end,

	disableCatch = function()
		shouldCatch = nil
		shouldFight = nil
	end,

	-- RED

	viridianExp = function()
		minExp = 210
		shouldFight = {{name="rattata",lvl={2,3}}, {name="pidgey",lvl={2}}}
	end,

	viridianBackupExp = function()
		minExp = 210
		shouldFight = {{name="rattata",lvl={2,3}}, {name="pidgey",lvl={2,3}}}
	end,

	nidoranBackupExp = function()
		minExp = 210
		shouldFight = {{name="rattata"}, {name="pidgey"}, {name="nidoran"}, {name="nidoranf",lvl={2}}}
	end,

	moon1Exp = function()
		minExp = 2704
		shouldFight = {{name="zubat",lvl={9,10}}}
		oneHits = true
	end,

	moon2Exp = function()
		minExp = 3011
		shouldFight = {{name="zubat"}, {name="paras"}}
		oneHits = not withinOneKill(minExp)
	end,

	moon3Exp = function()
		local expTotal = Pokemon.getExp()
		minExp = 3798
		if withinOneKill(minExp) then
			shouldFight = {{name="zubat"}, {name="geodude",lvl={9}}, {name="paras"}} --TODO geodude?
		else
			shouldFight = nil
		end
	end,

	catchNidoran = function()
		shouldCatch = {{name="nidoran",lvl={3,4}}, {name="spearow"}}
	end,

	catchFlier = function()
		shouldCatch = {{name="spearow",alt="pidgey",hp=15}, {name="pidgey",alt="spearow",hp=15}}
	end,

	catchParas = function()
		shouldCatch = {{name="paras",hp=16}}
	end,

	catchOddish = function()
		shouldCatch = {{name="oddish",alt="paras",hp=26}}
	end,

	-- YELLOW

	catchNidoranYellow = function()
		shouldCatch = {{name="nidoran",lvl={6}}}
	end,

	moonExpYellow = function()
		minExp = 2704 --TODO
		shouldFight = {{name="geodude"}, {name="clefairy",lvl={12,13}}}
		oneHits = true
	end,

	catchSandshrew = function()
		shouldCatch = {{name="sandshrew"}}
	end,

}

-- COMBAT

function Control.battlePotion(enable)
	potionInBattle = enable
end

function Control.canDie(enabled)
	if enabled == nil then
		return canDie
	end
	canDie = enabled
end

local function isNewFight()
	if fightEncounter < encounters and Memory.double("battle", "opponent_hp") == Memory.double("battle", "opponent_max_hp") then
		fightEncounter = encounters
		return true
	end
end

function Control.shouldFight()
	if not shouldFight then
		return false
	end
	local expTotal = Pokemon.getExp()
	if expTotal < minExp then
		local oid = Memory.value("battle", "opponent_id")
		local olvl = Memory.value("battle", "opponent_level")
		for i,p in ipairs(shouldFight) do
			if oid == Pokemon.getID(p.name) and (not p.lvl or Utils.match(olvl, p.lvl)) then
				if oneHits then
					local move = Combat.bestMove()
					if move and move.maxDamage * 0.925 < Memory.double("battle", "opponent_hp") then
						return false
					end
				end
				return true
			end
		end
	end
end

function Control.canCatch(partySize)
	if not partySize then
		partySize = Memory.value("player", "party_size")
	end
	local pokeballs = Inventory.count("pokeball")
	local minimumCount = (yellow and 3 or 4) - partySize
	if pokeballs < minimumCount then
		Strategies.reset("Not enough PokeBalls", pokeballs)
		return false
	end
	return true
end

function Control.shouldCatch(partySize)
	if maxEncounters and encounters > maxEncounters then
		local extraCount = extraEncounter and Pokemon.inParty(extraEncounter)
		if not extraCount or encounters > maxEncounters + 1 then
			Strategies.reset("Too many encounters", encounters)
			return false
		end
	end
	if not shouldCatch then
		return false
	end
	if not partySize then
		partySize = Memory.value("player", "party_size")
	end
	if partySize == 4 then
		shouldCatch = nil
		return false
	end
	if not Control.canCatch(partySize) then
		return true
	end
	local oid = Memory.value("battle", "opponent_id")
	for i,poke in ipairs(shouldCatch) do
		if oid == Pokemon.getID(poke.name) and not Pokemon.inParty(poke.name, poke.alt) then
			if not poke.lvl or Utils.match(Memory.value("battle", "opponent_level"), poke.lvl) then
				local penultimate = poke.hp and Memory.double("battle", "opponent_hp") > poke.hp
				if penultimate then
					penultimate = Combat.nonKill()
				end
				if penultimate then
					require("action.battle").fight(penultimate.midx, true)
				else
					Inventory.use("pokeball", nil, true)
				end
				return true
			end
		end
	end
end

-- Items

function Control.canRecover()
	return potionInBattle and (not battleYolo or not Control.yolo)
end

function Control.set(data)
	controlFunctions[data.c](data)
end

function Control.setYolo(enabled)
	Control.yolo = enabled
end

function Control.setPotion(enabled)
	potionInBattle = enabled
end

function Control.encounters()
	return encounters
end

function Control.wildEncounter()
	encounters = encounters + 1
	Paint.wildEncounters(encounters)
	Bridge.encounter()
	if Control.moonEncounters then
		Control.moonEncounters = Control.moonEncounters + 1
	end
end

function Control.reset()
	canDie = false
	oneHits = false
	shouldCatch = nil
	shouldFight = nil
	extraEncounter = nil
	potionInBattle = true
	encounters = 0
	fightEncounter = 0
	caveFights = 0
	battleYolo = false
	Control.yolo = false
	maxEncounters = nil
end

function Control.init()
	Strategies = require("ai."..GAME_NAME..".strategies")
end

return Control
