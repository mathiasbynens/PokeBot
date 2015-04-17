local Data

local Bridge = require "util.bridge"
local Utils = require "util.utils"
local Pokemon = require "storage.pokemon"

local version = 0
local vIndex = 2
for segment in string.gmatch(VERSION, "([^.]+)") do
	version = version + tonumber(segment) * 100 ^ vIndex
	vIndex = vIndex - 1
end

Data = {
	run = {},

	versionNumber = version,
}

function Data.increment(key)
	local incremented = Utils.increment(Data.run[key])
	Data.run[key] = incremented
	return incremented
end

function Data.reset(reason, areaName, map, px, py)
	-- if INTERNAL and STREAMING_MODE then --TODO
	if INTERNAL then
		local report = Data.run
		report.cutter = Pokemon.inParty("paras", "oddish", "sandshrew", "charmander")

		for key,value in pairs(report) do
			if value == true or value == false then
				report[key] = value == true and 1 or 0
			end
		end

		report.version = Data.versionNumber
		report.reset_area = areaName
		report.reset_map = map
		report.reset_x = px
		report.reset_y = py
		report.reset_reason = reason

		if not report.frames then
			report.frames = Utils.frames()
		end

		Bridge.report(report)
	end
	Data.run = {}
end

return Data
