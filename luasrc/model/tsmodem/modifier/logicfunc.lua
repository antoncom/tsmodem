
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"

local logic = {}

function logic:logicfunc(varname, setting) --[[
	Logicfunc modifier realization.
	Substitute values instead variables
	and check logic expression
	]]
	local varlink = setting[varname] or {}
	local modifier = varlink.target_modifier or {}
	local logic, result = '', true

	for name, value in util.kspairs(modifier) do
		if(name:sub(3) == "logicfunc") then
			logic = value

			for name, _ in pairs(setting) do
				if(type(setting[name].target_value) == "string") then
					logic = logic:gsub('"' .. name .. '"', '"' .. setting[name].target_value .. '"') or "return(false)"
				end
			end
			local func = loadstring(logic) or false -- If error in logic text then return False
			result = func and func() or false 		-- TODO make an error notification "Error in logicfunc!"
			if(varname == "journal") then
				--print("LOGICFUNC VALUE ", value)
				--print("LOGICFUNC LOGIC ", logic)
				--print("LOGICFUNC RESULT ", tostring(result))
			end
			
			break
		end
	end
	return result	
end

return logic