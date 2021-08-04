
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
	local logic_body, result = '', true

	for name, value in util.kspairs(modifier) do
		if(name:sub(3) == "logicfunc") then
			logic_body = value

			for name, _ in pairs(setting) do
				if(type(setting[name].target_value) == "string") then
					if(varname == "action") then
						-- print("LOGIC GSUB ", '"' .. name .. '"', '"' .. setting[name].target_value .. '"')
					end
					logic_body = logic_body:gsub('"' .. name .. '"', '"' .. setting[name].target_value .. '"') or "return(false)"
				end
			end

			local func = logic_body and loadstring(logic_body)
			if func then
				result = func()
			else
				print("ERROR in [" .. varname .. "] LOGICFUNC: " .. logic_body)
				return false
			end

			if not (result == true or result == false) then
				print("ERROR in [" .. varname .. "] LOGICFUNC returns NIL: " .. logic_body)
				result = false

--[[			else

				if(varname == "action" and result == false) then
					print("LOGICFUNC VALUE ", value)
					print("LOGICFUNC LOGIC ", logic_body)
				end	
				if(varname == "action" and result == true) then
					log(string.format("LOGIC [%s]", varname), setting[varname])
					print("LOGICFUNC VALUE ", value)
					print("LOGICFUNC LOGIC ", logic_body)
				end		
]]
			end

		end
	end
	return result	
end

return logic