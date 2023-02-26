

function parser(varname, parser_filename, setting)

	local varlink = setting[varname] or {}


	varlink.subtotal = require("luci.model." .. parser_filename):match(varlink.subtotal) or ""


end

return parser
