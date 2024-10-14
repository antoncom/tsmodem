local lpeg = require "lpeg"
local log = require "tsmodem.util.log"
local uci = require "luci.model.uci".cursor()
local balance_test = require "tsmodem.parser.balance"

function comma_to_point(s)
	local r = s:gsub(",", ".")
	return r
end

function balance_msg_text()
	local spc = lpeg.S(" \t\n\r")^0
	local pre = spc * lpeg.P("+CUSD: ") * lpeg.P(lpeg.R('09')^-2) * ',"'
	local body = lpeg.C(lpeg.P(1)^1)
	local msg = (pre * body) / function(s) return s:sub(1, -6) end
	return msg
end

return balance_msg_text


-- [[ For local testing ]]

-- [[ MTS ]]
--local text = [[+CUSD: 2,"Balance:633,100r"]]
--print(text)
--print(balance(1):match(text))

-- [[ BEELINE ]]
-- local text = [[+CUSD: 2," Vash balans 510.20 r.
--Slushajte 200 radiostantsij s bilajnom 1 den\' besplatno! Podkl: *279#", 17]]
--print(text)
--print(balance_test(0):match(balance_msg_text():match(text)))
