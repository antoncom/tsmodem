
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"


local main = {
	["formula"] = require "luci.model.tsmodem.modifier.formula",
	["parser"] = require "luci.model.tsmodem.modifier.parser",
	["ui-update"] = require "luci.model.tsmodem.modifier.ui_update",
}

function main:modify(varname, setting) --[[
	Apply modifiers to the target value
	---------------------------------]]

	local varlink = setting[varname] or {}


	-- Before the modifier apply, we load intermediate "subtotal"
	-- with the initial (input) value
	varlink.subtotal = varlink.subtotal or string.format("%s", tostring(varlink.input))


	-- If modifiers are existed, then modify input and save to output

	for modifier_name, modifier_value in util.kspairs(varlink.modifier) do

		if "formula" == modifier_name:sub(3) then
			local apply = main["formula"]
			apply(varname, modifier_value, setting)
		end

		if "parser" == modifier_name:sub(3) then
			local apply = main["parser"]
			apply(varname, modifier_value, setting)
		end

		if "ui-update" == modifier_name:sub(3) then
			local apply = main["ui-update"]
			apply(varname, modifier_value, setting)
		end

	end

	-- After all modifiers was applied, we put result to "output"
	if(varlink.subtotal) then
		if(type(varlink.subtotal) == "table") then
			varlink.output = util.serialize_json(varlink.subtotal)
		else
			--if(varname == "signal_normal_last_time") then print(":::: ", varlink.subtotal) end
			varlink.output = string.sub(varlink.subtotal, 1)
		end
		varlink.subtotal = nil
	end



--[[
	if varname == "lastreg_time" then
		print("1 lastreg_time = ", varlink.output)
	end

	if varname == "lastreg_timer" then
		print("R lastreg_timer = ", varlink.output)
	end
]]



end

return main
