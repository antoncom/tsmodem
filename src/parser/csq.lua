local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0


local csq0 = lpeg.P('+CSQ: ') *
		lpeg.C(lpeg.R('09')^-2) * ','

-- AT+CREG?\r\r\n+CREG: 0,6\r\n\r\nOK\r\n
local csq1 = spc * lpeg.P('AT+CSQ') * spc *
		lpeg.P('+CSQ: ') *
		lpeg.C(lpeg.R('09')^-2) * ',' * spc

local csq2 = spc * lpeg.P('+CSQ: ') *
		lpeg.C(lpeg.R('09')^-2) * ',' * spc


local csq = csq0 + csq1 + csq2

return csq

--local text = "AT+CSQ\n\r\r+CSQ: 0,0\r\n+CGEV: EPS PDN ACT 1\n\r"

--print(csq:match(text))
--print(csq:match("+CSQ: 0,99"))
--print(csq:match("AT+CSQ+CSQ: 1,99"))
--print(csq:match("AT+CSQ+CSQ: 19,0"))
