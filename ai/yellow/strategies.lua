local Strategies = require "ai.strategies"

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

local status = Strategies.status

-- TIME CONSTRAINTS

Strategies.timeRequirements = {}

-- STRATEGIES

local strategyFunctions = Strategies.functions

-- PROCESS

function Strategies.initGame(midGame)
	if not STREAMING_MODE then
		-- Strategies.setYolo("")
	end
end

function Strategies.completeGameStrategy()
	status = Strategies.status
end

function Strategies.resetGame()
	status = Strategies.status
end

return Strategies
