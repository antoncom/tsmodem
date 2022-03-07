local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"
local uci = require "luci.model.uci".cursor()



function balance(sim_id)
	local provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	local balance_mask = provider_id and uci:get("tsmodem_adapter_provider", provider_id, "balance_mask")
	local n_RUB = balance_mask and balance_mask:find("__RUB__")
	local first_chunk = n_RUB and balance_mask:sub(1, n_RUB - 1)
	local spc = lpeg.S(" \t\n\r")^0

	local balance_value =  first_chunk and (spc * lpeg.P(first_chunk) * spc *
				lpeg.C(
				  lpeg.P('-')^-1 *
				  lpeg.R('09')^0 *
				  (
					  lpeg.S('.,') *
					  lpeg.R('09')^0
				  )^-1 ) /
				tonumber)

	return balance_value or ""
end

return balance



--local text = string.gsub('Баланс: 10,2 р.', ",", ".")

--print(balance:match(text))
