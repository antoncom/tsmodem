

function formula(varname, formula, setting) --[[
	Apply modifiers to the target value
	---------------------------------]]
	local varlink = setting[varname] or {}

	-- Replace all variables with actual values

	local luacode = (function(chunk) 
		for name, _ in pairs(setting) do
			if(type(setting[name].target_value) == "string") then
				chunk = chunk:gsub('"' .. name .. '"', '"' .. setting[name].target_value .. '"')
			end
		end
		return chunk
	end)(formula)

	-- Run chunk code and put result to target

	local func = luacode and loadstring(luacode)
	if func then
		varlink.target_value = func() or "" -- TODO make an error notification "Error in Formula!"
	else
		print("ERROR in [" .. varname .. "] FORMULA: " .. formula)
	end


--[[
	if(varname == "lastreg_timer") then
		print("----------------")
		print("FORMULA " .. varname)
		print("FORMULA chunk" .. formula)
		print("FORMULA luacode" .. luacode)
		print("FORMULA result" .. varlink.target_value)
	end
]]


end

return formula