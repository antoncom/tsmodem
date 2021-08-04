

function parser(varname, parser_filename, setting)

	local varlink = setting[varname] or {}

	-- Parse and modify target value according to parser

--	if(varname == "network_registration") then
--		print("PARSER\n------\n\r", varlink.target_value)
--	end

	varlink.target_value = require("luci.model." .. parser_filename):match(varlink.target_value) or ""


end

return parser