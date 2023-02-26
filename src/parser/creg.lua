local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0


local creg0 = lpeg.P('+CREG: 0,') *
		lpeg.C(lpeg.R('05'))

-- AT+CREG?\r\r\n+CREG: 0,6\r\n\r\nOK\r\n
local creg1 = spc * lpeg.P('AT+CREG?') * spc *
		lpeg.P('+CREG: 0,') *
		lpeg.C(lpeg.R('05')) * spc
--		lpeg.C(lpeg.R('05')) * spc *
--		lpeg.P('OK') * spc

local creg2 = spc * lpeg.P('+CREG: 0,') *
		lpeg.C(lpeg.R('05')) * spc



local creg = creg0 + creg1 + creg2

return creg

--local text = "AT+CREG?\n\r\r+CREG: 0,0\r\n+CGEV: EPS PDN ACT 1\n\r"
--print(text)
--print(creg:match(text))
--print(creg:match("AT+CREG?+CREG: 0,5"))
--print(creg:match("AT+CREG?+CREG: 0,1OK"))
--print(creg:match("AT+CREG?+CREG: 0,1OK"))
