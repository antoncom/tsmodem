

function formula(varname, formula, setting) --[[
	Apply modifiers to the target value
	---------------------------------]]
	local varlink = setting[varname] or {}

	-- Replace all variables with actual values

	--print("FORMULA ", formula)

	local luacode = (function(chunk) 
		for name, _ in pairs(setting) do
			if(type(setting[name].target_value) == "string") then
				chunk = chunk:gsub('"' .. name .. '"', '"' .. setting[name].target_value .. '"')
			end
		end
		return chunk
	end)(formula)

	-- Run chunk code and put result to target

	varlink.target_value = loadstring(luacode)() or ""

end

return formula