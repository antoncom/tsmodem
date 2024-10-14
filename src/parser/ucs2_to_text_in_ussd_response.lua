local lpeg = require "lpeg"
local log = require "tsmodem.util.log"
local uci = require "luci.model.uci".cursor()

local ucs2 = require "tsmodem.parser.ucs2_ascii"

function comma_to_point(s)
	local r = s:gsub(",", ".")
	return r
end

function balance_ussd_response_with_ucs2()
	local spc = lpeg.S(" \t\n\r")^0
	local balance_ussd_response_converted_to_text = spc * lpeg.P("+CUSD: ") * lpeg.P(lpeg.R('09')^-2) * ',"' *
		lpeg.C(
			lpeg.S('0123456789abcdefABCDEF')^4
		) * lpeg.P('", 17')^1 / ucs2
	return balance_ussd_response_converted_to_text
end




--return balance_ussd_response_with_ucs2


-- [[ For local testing ]]

-- [[ MTS ]]
--local text = [[+CUSD: 2,"Balance:633,100r"]]
--print(text)
--print(balance(1):match(text))

-- [[ BEELINE ]]
--local text = [[+CUSD: 2," Vash balans 510.20 r.
--Slushajte 200 radiostantsij s bilajnom 1 den\' besplatno! Podkl: *279#]]

local text = [[+CUSD: 2,"003600310031002e0032003000200440002e", 17]]
print(text)
print(balance_ussd_response_with_ucs2():match(text))
