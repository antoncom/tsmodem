
local sys  = require "luci.sys"
local util = require "luci.util"


local regular = {
	["formula"] = require "luci.model.tsmodem.parser.formula",
	["parser"] = require "luci.model.tsmodem.parser.parser",
	["ui_update"] = require "luci.model.tsmodem.parser.ui_update",
}

function regular:modify(varname, setting) --[[
	Apply modifiers to the target value
	---------------------------------]]
	local varlink = setting[varname] or {}

	-- Firstly, we put unmodified source data to target

	varlink.target_value = varlink.source_value

	-- If modifiers are existed, then modify the target value

	local modifier = varlink.target_modifier or {}
	for modifier_name, modifier_value in util.kspairs(modifier) do

		if "formula" == modifier_name:sub(3) then
			local formula = modifier_value

			-- Replace all variables with actual values

			local luacode = (function(chunk) 
				for name, _ in pairs(setting) do
					if(type(setting[name].target_value) == "string") then
						chunk = chunk:gsub('"' .. name .. '"', '"' .. setting[name].target_value .. '"')
					end
				end
				return chunk
			end)(formula)

			-- Run chunk code and save result

			-- luacode = string.gsub(luacode, varname, varlink.target_value) or "return(false)"
			varlink.target_value = loadstring(luacode)() or string.format("No Formula result for '%s'", varname)

		end

		if "parser" == modifier_name:sub(3) then
			local parser = modifier_value
			varlink.target_value = require("luci.model." .. parser):match(varlink.target_value) or string.format("No parsing result for '%s'", varname)
		end

		if "ui-update" == modifier_name:sub(3) then
			local ui_data, param_list = '', modifier[modifier_name].param_list or {}

			-- Prepare params to send to UI
			local params = {}
			for i=1, #param_list do
				params[param_list[i]] = setting[param_list[i]].target_value
			end

			ui_data = util.serialize_json(params)
			sys.exec(string.format("echo '%s' > /tmp/wspipein.fifo", ui_data))
		end

	end
end

return regular