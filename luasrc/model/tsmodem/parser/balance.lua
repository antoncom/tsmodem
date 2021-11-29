local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"
local uci = require "luci.model.uci".cursor()



function balance(sim_id, provider_id)
	local balance_value = ""
	local provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	local balance_mask = uci:get("tsmodem_adapter_provider", provider_id, "balance_mask")
	local n_RUB = balance_mask:find("__RUB__")
	if n_RUB then
		local first_chunk = balance_mask:sub(1, n_RUB - 1)
		local spc = lpeg.S(" \t\n\r")^0
		balance_value =   spc * lpeg.P(first_chunk) * spc *
					lpeg.C(
					  lpeg.P('-')^-1 *
					  lpeg.R('09')^0 *
					  (
						  lpeg.S('.,') *
						  lpeg.R('09')^0
					  )^-1 ) /
					tonumber
	end

	return balance_value
end

return balance



--local text = string.gsub('Баланс: 10,2 р.', ",", ".")

--print(balance:match(text))
