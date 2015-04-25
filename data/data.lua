local Data

local version = 0
if VERSION then
	local vIndex = 2
	for segment in string.gmatch(VERSION, "([^.]+)") do
		version = version + tonumber(segment) * 100 ^ vIndex
		vIndex = vIndex - 1
	end
end

local yellowVersion = memory.getcurrentmemorydomainsize() > 30000

Data = {
	run = {},

	yellow = yellowVersion,
	gameName = yellowVersion and "yellow" or "red",
	versionNumber = version,
}

-- PRIVATE

local function increment(amount)
	if not amount then
		return 1
	end
	return amount + 1
end

-- HELPERS

function Data.setFrames()
	Data.run.frames = require("util.utils").frames()
end

function Data.increment(key)
	local incremented = increment(Data.run[key])
	Data.run[key] = incremented
	return incremented
end

-- REPORT

function Data.reset(reason, areaName, map, px, py)
	if STREAMING_MODE then
		local report = Data.run
		report.cutter = require("storage.pokemon").inParty("paras", "oddish", "sandshrew", "charmander")

		for key,value in pairs(report) do
			if value == true or value == false then
				report[key] = value == true and 1 or 0
			end
		end

		report.version = Data.versionNumber
		report.gameName = Data.gameName

		report.reset_area = areaName
		report.reset_map = map
		report.reset_x = px
		report.reset_y = py
		report.reset_reason = reason

		if not report.frames then
			Data.setFrames()
		end

		require("util.bridge").report(report)
	end
	Data.run = {}
end

return Data
