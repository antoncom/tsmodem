

function formula(varname, formula, setting) --[[
	Apply modifiers to the target value
	---------------------------------]]
	local varlink = setting[varname] or {}

	-- Replace all variables with actual values

	local luacode = (function(chunk)
		for name, _ in pairs(setting) do
			if name ~= varname then
				if(type(setting[name].output) == "string") then
					--chunk = chunk:gsub('"' .. name .. '"', '"' .. setting[name].output .. '"')
					chunk = chunk:gsub(name, setting[name].output)
				end
			else --[[ 	If formula has current variable name, substitute subtotal instead of output
						because output value will be set after all modifiers have been applied.
			]]
				if(type(setting[name].subtotal) == "string") then
					--chunk = chunk:gsub('"' .. name .. '"', '"' .. setting[name].subtotal .. '"')
					chunk = chunk:gsub(name, setting[name].subtotal)
				end
			end
		end
		return chunk
	end)(formula)

	--print(":::::::: " .. varname, luacode)
	--log(varname, varlink)
	local func = luacode and loadstring(luacode)
	if func then
		varlink.subtotal = func() or error("Formula chunk error for " .. varname .. '\n' .. luacode) -- TODO make an error notification "Error in Formula!"
	else
		print("ERROR in [" .. varname .. "] FORMULA: " .. luacode)
	end




end

return formula
