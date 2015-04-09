-- OPTIONS

RESET_FOR_TIME = true -- Set to false if you just want to see the bot finish a run

local CUSTOM_SEED = nil -- Set to a known seed to replay it, or leave nil for random runs
local PAINT_ON    = true -- Display contextual information while the bot runs

-- START CODE (hard hats on)

VERSION = "1.3"
YELLOW = memory.getcurrentmemorydomainsize() > 30000
GAME_NAME = YELLOW and "yellow" or "red"

local START_WAIT = 99

local Battle = require "action.battle"
local Textbox = require "action.textbox"
local Walk = require "action.walk"

local Combat = require "ai.combat"
local Control = require "ai.control"
local Strategies = require("ai."..GAME_NAME..".strategies")

local Bridge = require "util.bridge"
local Input = require "util.input"
local Memory = require "util.memory"
local Menu = require "util.menu"
local Paint = require "util.paint"
local Utils = require "util.utils"
local Settings = require "util.settings"

local Pokemon = require "storage.pokemon"

local hasAlreadyStartedPlaying = false
local oldSecs
local running = true
local lastHP

-- GLOBAL

function p(...)
	local string
	if #arg == 0 then
		string = arg[0]
	else
		string = ""
		for i,str in ipairs(arg) do
			if str == true then
				string = string.."\n"
			else
				string = string..str.." "
			end
		end
	end
	print(string)
end

-- HELPERS

local function resetAll()
	Strategies.softReset()
	Combat.reset()
	Control.reset()
	Walk.reset()
	Paint.reset()
	Bridge.reset()
	oldSecs = 0
	running = false
	-- client.speedmode = 200

	if CUSTOM_SEED then
		Strategies.seed = CUSTOM_SEED
		p("RUNNING WITH A FIXED SEED ("..Strategies.seed.."), every run will play out identically!", true)
	else
		Strategies.seed = os.time()
	end
	math.randomseed(Strategies.seed)
end

-- EXECUTE

p("Welcome to PokeBot "..GAME_NAME.." version "..VERSION, true)

Control.init()

STREAMING_MODE = not Walk.init()
if INTERNAL and STREAMING_MODE then
	RESET_FOR_TIME = true
end

if CUSTOM_SEED then
	client.reboot_core()
else
	hasAlreadyStartedPlaying = Utils.ingame()
end

Strategies.init(hasAlreadyStartedPlaying)
if RESET_FOR_TIME and hasAlreadyStartedPlaying then
	RESET_FOR_TIME = false
	p("Disabling time-limit resets as the game is already running. Please reset the emulator and restart the script if you'd like to go for a fast time.", true)
end
if STREAMING_MODE then
	Bridge.init()
else
	Input.setDebug(true)
end

-- Main loop

local previousMap

while true do
	local currentMap = Memory.value("game", "map")
	if currentMap ~= previousMap then
		Input.clear()
		previousMap = currentMap
	end
	if Strategies.frames then
		if Memory.value("game", "battle") == 0 then
			Strategies.frames = Strategies.frames + 1
		end
		Utils.drawText(0, 80, Strategies.frames)
	end
	if Bridge.polling then
		Settings.pollForResponse()
	end

	if not Input.update() then
		if not Utils.ingame() then
			if currentMap == 0 then
				if running then
					if not hasAlreadyStartedPlaying then
						client.reboot_core()
						hasAlreadyStartedPlaying = true
					else
						resetAll()
					end
				else
					Settings.startNewAdventure(START_WAIT)
				end
			else
				if not running then
					Bridge.liveSplit()
					running = true
				end
				Settings.choosePlayerNames()
			end
		else
			local battleState = Memory.value("game", "battle")
			Control.encounter(battleState)
			local curr_hp = Pokemon.index(0, "hp")
			-- if curr_hp ~= lastHP then
			-- 	Bridge.hp(curr_hp, Pokemon.index(0, "max_hp"))
			-- 	lastHP = curr_hp
			-- end
			if curr_hp == 0 and not Control.canDie() and Pokemon.index(0) > 0 then
				Strategies.death(currentMap)
			elseif Walk.strategy then
				if Strategies.execute(Walk.strategy) then
					Walk.traverse(currentMap)
				end
			elseif battleState > 0 then
				if not Control.shouldCatch(partySize) then
					Battle.automate()
				end
			elseif Textbox.handle() then
				Walk.traverse(currentMap)
			end
		end
	end

	if STREAMING_MODE then
		local newSecs = Memory.raw(0x1A44)
		if newSecs ~= oldSecs and (newSecs > 0 or Memory.raw(0x1A45) > 0) then
			Bridge.time(Utils.elapsedTime())
			oldSecs = newSecs
		end
	elseif PAINT_ON then
		Paint.draw(currentMap)
	end

	Input.advance()
	emu.frameadvance()
end

Bridge.close()
