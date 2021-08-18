
local sys  = require "luci.sys"
local util = require "luci.util"


local modifier = {
	["formula"] = require "luci.model.tsmodem.modifier.formula",
	["parser"] = require "luci.model.tsmodem.modifier.parser",
	["ui_update"] = require "luci.model.tsmodem.modifier.ui_update",
}

function modifier:modify(varname, setting) --[[
	Apply modifiers to the target value
	---------------------------------]]
	local varlink = setting[varname] or {}

	-- Firstly, we put unmodified source data to target

	varlink.target_value = varlink.source_value

	-- If modifiers are existed, then modify the target value

	local modifier = varlink.target_modifier or {}
	for modifier_name, modifier_value in util.kspairs(modifier) do

		if "formula" == modifier_name:sub(3) then
			local apply = modifier["formula"]
			apply(varname, modifier_value, setting)
		end

		if "parser" == modifier_name:sub(3) then
			local apply = modifier["parser"]
			apply(varname, modifier_value, setting)
		end

		if "ui_update" == modifier_name:sub(3) then
			local apply = modifier["ui_update"]
			apply(varname, modifier_value, setting)
		end

	end
end

return modifier