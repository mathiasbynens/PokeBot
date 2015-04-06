local Paint = {}

local Memory = require "util.memory"
local Player = require "util.player"
local Utils = require "util.utils"

local Pokemon = require "storage.pokemon"

local encounters = 0
local elapsedTime = Utils.elapsedTime

function Paint.draw(currentMap)
	local px, py = Player.position()
	gui.text(0, 14, currentMap..": "..px.." "..py)
	gui.text(0, 0, elapsedTime())

	if Memory.value("battle", "our_id") > 0 then
		local hp = Pokemon.index(0, "hp")
		local hpStatus
		if hp == 0 then
			hpStatus = "DEAD"
		elseif hp <= math.ceil(Pokemon.index(0, "max_hp") * 0.2) then
			hpStatus = "RED"
		end
		if hpStatus then
			gui.text(120, 7, hpStatus)
		end
	end

	local nidx = Pokemon.indexOf("nidoran", "nidorino", "nidoking")
	if nidx ~= -1 then
		local att = Pokemon.index(nidx, "attack")
		local def = Pokemon.index(nidx, "defense")
		local spd = Pokemon.index(nidx, "speed")
		local scl = Pokemon.index(nidx, "special")
		gui.text(100, 0, att.." "..def.." "..spd.." "..scl)
	end
	local enc = " encounter"
	if encounters ~= 1 then
		enc = enc.."s"
	end
	gui.text(0, 116, Memory.value("battle", "critical"))
	gui.text(0, 125, Memory.value("player", "repel"))
	gui.text(0, 134, encounters..enc)
	return true
end

function Paint.wildEncounters(count)
	encounters = count
end

function Paint.reset()
	encounters = 0
end

return Paint
