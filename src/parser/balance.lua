local lpeg = require "lpeg"
local log = require "tsmodem.util.log"
local uci = require "luci.model.uci".cursor()

function balance(sim_id)
	local provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	local balance_mask = provider_id and uci:get("tsmodem_adapter_provider", provider_id, "balance_mask")
	local n_RUB = balance_mask and balance_mask:find("__RUB__")
	local first_chunk = n_RUB and balance_mask:sub(1, n_RUB - 1) or ""

	local spc = lpeg.S(" \t\n\r")^0

	local balance_value = spc * lpeg.P("+CUSD: ") * lpeg.P(lpeg.R('09')^-2) * ',"' *
								lpeg.P(first_chunk) * spc *
								lpeg.C(
									lpeg.P('-')^-1 *
								 	lpeg.R('09')^0 *
								  	(
										lpeg.S('.,') *
									  	lpeg.R('09')^0
								  	)^-1
								) / tonumber
	return balance_value
end

return balance


-- [[ For local testing ]]

-- [[ MTS ]]
-- local text = [[+CUSD: 2,"Balance:633r"]]
-- print(text)
-- print(balance(0):match(text))

-- [[ BEELINE ]]
-- local text = [[+CUSD: 2," Vash balans 510.20 r.
-- Slushajte 200 radiostantsij s bilajnom 1 den\' besplatno! Podkl: *279#]]
-- print(text)
-- print(balance(1):match(text))
