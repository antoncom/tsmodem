

function parser(varname, parser_filename, setting)

	local varlink = setting[varname] or {}

	-- Parse and modify target value according to parser

	varlink.target_value = require("luci.model." .. parser_filename):match(varlink.target_value) or ""


end

return parser