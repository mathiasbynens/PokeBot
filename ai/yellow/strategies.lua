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

local status = Strategies.status
local stats = Strategies.stats

local strategyFunctions = Strategies.functions

-- TIME CONSTRAINTS

Strategies.timeRequirements = {}

-- STRATEGIES

local strategyFunctions = Strategies.functions

-- PROCESS

function Strategies.initGame(midGame)
	if not STREAMING_MODE then
		-- Strategies.setYolo("")
		if Pokemon.inParty("nidoking") then
			stats.nidoran = {
				attack = 55,
				defense = 45,
				speed = 50,
				special = 45,
			}
		else
			stats.nidoran = {
				attack = 16,
				defense = 12,
				speed = 15,
				special = 13,
				level4 = true,
			}
		end
	end
end

function Strategies.completeGameStrategy()
	status = Strategies.status
end

function Strategies.resetGame()
	status = Strategies.status
	stats = Strategies.stats
end

return Strategies
