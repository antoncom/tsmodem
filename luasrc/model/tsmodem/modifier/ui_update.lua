
local util = require "luci.util"
local sys  = require "luci.sys"


function ui_update(varname, modifier, setting)

	print("UI " .. varname)

	local varlink = setting[varname] or {}
	local param_list = modifier.param_list or {}

	-- Prepare params to send to UI
	local params = {}
	for i=1, #param_list do
		params[param_list[i]] = setting[param_list[i]].target_value
	end

	local ui_data = util.serialize_json(params)
	sys.exec(string.format("echo '%s' > /tmp/wspipein.fifo", ui_data))

end

return ui_update