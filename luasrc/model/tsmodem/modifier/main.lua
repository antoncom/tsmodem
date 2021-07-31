
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

	-- Firstly, we put unmodified source data to target

	varlink.target_value = varlink.source_value

	-- If modifiers are existed, then modify the target value

	local modifiers = varlink.target_modifier or {}
	for modifier_name, modifier_value in util.kspairs(modifiers) do

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
end

return main