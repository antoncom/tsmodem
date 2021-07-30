local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0

-- AT+CREG?\r\r\n+CREG: 0,6\r\n\r\nOK\r\n
local creg = spc * lpeg.P('AT+CREG?') * spc *
		lpeg.P('+CREG: 0,') *
		lpeg.C(lpeg.R('05')) * spc
--		lpeg.C(lpeg.R('05')) * spc *
--		lpeg.P('OK') * spc

return creg

--local text = "AT+CREG?\n\r\r+CREG: 0,0\r\n+CGEV: EPS PDN ACT 1\n\r"
--print(text)
--print(creg:match(text))
--print(creg:match("AT+CREG?\r\n+CREG: 0,5\r\n"))



