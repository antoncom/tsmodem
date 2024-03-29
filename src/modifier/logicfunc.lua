
local util = require "luci.util"
local log = require "tsmodem.util.log"

local logic = {}

function logic:logicfunc(varname, setting) --[[
	Logicfunc modifier realization.
	Substitute values instead variables
	and check logic expression
	]]
	local varlink = setting[varname] or {}
	local logic_body, result, status = '', true, true

	for name, value in util.kspairs(varlink.modifier) do
		if(name:sub(3) == "logicfunc") then
			logic_body = value

			for name, _ in pairs(setting) do
				if(type(setting[name].output) == "string") then
					logic_body = logic_body:gsub('"' .. name .. '"', '"' .. setting[name].output .. '"') or "return(false)"
				end
			end


			--if(varname == "do_switch_low_signal") then
				--log(varname, logic_body)
			--end


			local func = logic_body and loadstring(logic_body)
			if func then
				status, result = pcall(func)
				if status == false then
					print("ERROR in [" .. varname .. "] LOGICFUNC: " .. result)
					log(varname, logic_body)
					return false
				end
			else
				print("ERROR in [" .. varname .. "] LOGICFUNC: " .. logic_body)
				log(varname, logic_body)
				return false
			end

			if not (result == true or result == false) then
				print("ERROR in [" .. varname .. "] LOGICFUNC returns NIL: " .. logic_body)
				log(varname, logic_body)
				result = false

			end

		end
	end
	return result
end

return logic
