local utils = {}

local memory = require "util.memory"

function utils.dist(x1, y1, x2, y2)
	return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2))
end

function utils.ingame()
	return memory.raw(0x020E) > 0
end

function utils.each(table, func)
	for key,val in pairs(table) do
		func(key.." = "..tostring(val)..",")
	end
end

function utils.eachi(table, func)
	for idx,val in ipairs(table) do
		if val then
			func(idx.." "..val)
		else
			func(idx)
		end
	end
end

function utils.match(needle, haystack)
	for i,val in ipairs(haystack) do
		if needle == val then
			return true
		end
	end
	return false
end

function utils.key(needle, haystack)
	for key,val in pairs(haystack) do
		if needle == val then
			return key
		end
	end
	return nil
end

function utils.igt()
	local secs = memory.raw(0xDA44)
	local mins = memory.raw(0xDA43)
	local hours = memory.raw(0xDA41)
	return secs + mins * 60 + hours * 3600
end

function utils.onPokemonSelect(battleMenu)
	return battleMenu == 8 or battleMenu == 48 or battleMenu == 184 or battleMenu == 224
end

-- TIME

local function clockSegment(unit)
	if unit < 10 then
		unit = "0"..unit
	end
	return unit
end

function utils.timeSince(prevTime)
	local currTime = utils.igt()
	local diff = currTime - prevTime
	local timeString
	if diff > 0 then
		local mins = math.floor(diff / 60)
		local secs = mins % 60
		timeString = clockSegment(mins)..":"..clockSegment(secs)
	end
	return currTime, timeString
end

function utils.elapsedTime()
	local secs = memory.raw(0xDA44)
	if secs < 10 then
		secs = "0"..secs
	end
	local mins = memory.raw(0xDA43)
	if mins < 10 then
		mins = "0"..mins
	end
	return memory.raw(0xDA41)..":"..mins..":"..secs
end

return utils
