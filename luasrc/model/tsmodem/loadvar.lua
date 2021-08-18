
function loadvar(rule, varname, ...)
	local initval = arg[1]
	local varlink = rule.setting[varname]
	varlink.subtotal = nil

	if(rule:logicfunc(varname) == true) then

		if initval then --[[ Get value from initial]]

			varlink.input = initval

		else --[[ Get value from UBUS]]

			if(varlink.source) then
				local ubus_obj = varlink.source.model or ""
				local method = varlink.source.method
				local param = varlink.source.param

				method = varlink.source.method
				
				local resp = rule.conn:call(ubus_obj, method, {})
				--print(varname, param)
				--log(varname, resp)
				varlink.input = param and resp[param] or ""
			end

		end

	end


	-- Make function chaning like this:
	-- rule:load("title"):modify()
	local mdf = {}
	function mdf:modify()

		-- Apply modifiers only if Logic func returns true
		if(rule:logicfunc(varname) == true) then
			rule:modify(varname)
		end

	end
	local modify_metatable = {
		__call = function(table)
			return table
		end
	}
	setmetatable(mdf, modify_metatable)
	return mdf

end

return loadvar