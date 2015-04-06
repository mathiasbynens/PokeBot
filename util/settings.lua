local settings = {}

local memory = require "util.memory"
local menu = require "util.menu"

local yellow = YELLOW

local settings_menu
if yellow then
	settings_menu = 93
else
	settings_menu = 94
end

local desired = {}
if yellow then
	desired.text_speed = 1
	desired.battle_animation = 128
	desired.battle_style = 64
else
	desired.text_speed = 1
	desired.battle_animation = 10
	-- desired.battle_style =
end

local function isEnabled(name)
	if yellow then
		local matching = {
			text_speed = 0xF,
			battle_animation = 128,
			battle_style = 64
		}
		local settingMask = memory.value("setting", "yellow_bitmask", true)
		return bit.band(settingMask, matching[name]) == desired[name]
	else
		return memory.value("setting", name) == desired[name]
	end
end

function settings.set(...)
	for i,name in ipairs(arg) do
		if not isEnabled(name) then
			if menu.open(settings_menu, 1) then
				menu.setOption(name, desired[name])
			end
			return false
		end
	end
	return menu.cancel(settings_menu)
end

return settings
