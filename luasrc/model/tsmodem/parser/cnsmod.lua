local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"

spc = lpeg.S(" \t\n\r")^0

local cnsmod = spc * lpeg.P('+CNSMOD: ') *
		lpeg.C(lpeg.R('09')^-2)

return cnsmod

--local text = "\n\n+CNSMOD: 1,1\r\n"
-- local text = "\n\n+CNSMOD: 1\r\n"
--local text = "+CNSMOD: 1\r\n"

--print(text)
--print(res)
--print(csq:match("+CSQ: 0,99"))
--print(csq:match("AT+CSQ+CSQ: 1,99"))
--print(csq:match("AT+CSQ+CSQ: 19,0"))
