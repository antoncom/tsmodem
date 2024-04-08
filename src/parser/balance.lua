local lpeg = require "lpeg"
local log = require "tsmodem.util.log"
local uci = require "luci.model.uci".cursor()
--local ucs2_ascii = require "tsmodem.parserucs2_ascii"

function comma_to_point(s)
	local r = s:gsub(",", ".")
	return r
end

function balance(sim_id)
	local provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	local balance_mask = provider_id and uci:get("tsmodem_adapter_provider", provider_id, "balance_mask")
	local n_RUB = balance_mask and balance_mask:find("__RUB__")
	local first_chunk = n_RUB and balance_mask:sub(1, n_RUB - 1) or ""

	--print("provider_id:", provider_id)
	--print("balance_mask:", balance_mask)
	--print("first_chunk:", first_chunk)
	--print("n_RUB:", n_RUB)

	local spc = lpeg.S(" \t\n\r")^0

	--local balance_value = spc * lpeg.P("+CUSD: ") * lpeg.P(lpeg.R('09')^-2) * ',"' *
	local balance_value = spc * lpeg.P(first_chunk) * spc *
								lpeg.C(
									lpeg.P('-')^-1 *
								 	lpeg.R('09')^0 *
								  	(
										lpeg.S('.,') *
									  	lpeg.R('09')^0
								  	)^-1
								) / comma_to_point / tonumber
	return balance_value
end

return balance


-- [[ For local testing ]]

-- [[ MTS ]]
--local text = [[+CUSD: 2,"Balance:633,100r"]]
--print(text)
--print(balance(1):match(text))

-- [[ BEELINE ]]
--local text = [[1201.5 р.]]
--print("text:", text)
--print("balance:",balance(1):match(text))
