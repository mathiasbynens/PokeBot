local Utils = {}

local Memory = require "util.memory"

local yellow = YELLOW

-- GENERAL

function Utils.dist(x1, y1, x2, y2)
	return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2))
end

function Utils.each(table, func)
	for key,val in pairs(table) do
		func(key.." = "..tostring(val)..",")
	end
end

function Utils.eachi(table, func)
	for idx,val in ipairs(table) do
		if val then
			func(idx.." "..val)
		else
			func(idx)
		end
	end
end

function Utils.match(needle, haystack)
	for i,val in ipairs(haystack) do
		if needle == val then
			return true
		end
	end
	return false
end

function Utils.key(needle, haystack)
	for key,val in pairs(haystack) do
		if needle == val then
			return key
		end
	end
	return nil
end

function Utils.capitalize(string)
	return string:sub(1, 1):upper()..string:sub(1)
end

-- GAME

function Utils.canPotionWith(potion, forDamage, curr_hp, max_hp)
	local potion_hp
	if potion == "full_restore" then
		potion_hp = 9001
	elseif potion == "super_potion" then
		potion_hp = 50
	else
		potion_hp = 20
	end
	return math.min(curr_hp + potion_hp, max_hp) >= forDamage - 1
end

function Utils.ingame()
	return Memory.raw(0x020E) > 0
end

function Utils.onPokemonSelect(battleMenu)
	if yellow then
		return battleMenu == 27 or battleMenu == 243
	end
	return battleMenu == 8 or battleMenu == 48 or battleMenu == 184 or battleMenu == 224
end

-- TIME

function Utils.igt()
	local secs = Memory.raw(0x1A44)
	local mins = Memory.raw(0x1A43)
	local hours = Memory.raw(0x1A41)
	return secs + mins * 60 + hours * 3600
end

local function clockSegment(unit)
	if unit < 10 then
		unit = "0"..unit
	end
	return unit
end

function Utils.timeSince(prevTime)
	local currTime = Utils.igt()
	local diff = currTime - prevTime
	local timeString
	if diff > 0 then
		local secs = diff % 60
		local mins = math.floor(diff / 60)
		timeString = clockSegment(mins)..":"..clockSegment(secs)
	end
	return currTime, timeString
end

function Utils.elapsedTime()
	local secs = Memory.raw(0x1A44)
	if secs < 10 then
		secs = "0"..secs
	end
	local mins = Memory.raw(0x1A43)
	if mins < 10 then
		mins = "0"..mins
	end
	return Memory.raw(0x1A41)..":"..mins..":"..secs
end

function Utils.frames()
	local totalFrames = Memory.raw(0x1A41) * 60
	totalFrames = (totalFrames + Memory.raw(0x1A43)) * 60
	totalFrames = (totalFrames + Memory.raw(0x1A44)) * 60
	return totalFrames + Memory.raw(0x1A45)
end

return Utils
