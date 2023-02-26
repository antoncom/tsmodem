local lpeg = require "lpeg"
local log = require "tsmodem.util.log"

spc = lpeg.S(" \t\n\r")^0

local cnsmod = spc * lpeg.P('+CNSMOD: ') * lpeg.P(lpeg.R('01')^-1) * "," *
		lpeg.C(lpeg.R('09')^-2)

return cnsmod

--local text = "\n\n+CNSMOD: 0,8\r\n"
--print(cnsmod:match(text))
