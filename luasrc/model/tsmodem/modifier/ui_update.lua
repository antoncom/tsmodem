
local util = require "luci.util"
local sys  = require "luci.sys"


function ui_update(varname, modifier, setting)

	local varlink = setting[varname] or {}
	local param_list = modifier.param_list or {}

	-- Prepare params to send to UI
	local params, name = {}, ''
	for i=1, #param_list do
		name = param_list[i]
		if name == varname then
			if util.contains({ "journal_reg", "journal_usb", "journal_stm" }, name) then
				name = "journal"
			end
			params[name] = varlink.subtotal or ""
		else
			params[name] = setting[name].output or ""
		end
	end

	local ui_data = util.serialize_json(params)
	sys.exec(string.format("echo '%s' > /tmp/wspipein.fifo", ui_data))

end

return ui_update
