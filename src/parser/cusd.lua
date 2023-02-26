local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0


local cusd = spc * lpeg.P('+CUSD: ') *
		lpeg.P(lpeg.R('09')^-2) * ',"' *
		lpeg.C(lpeg.S('0123456789abcdef')^4) * '",' * spc

return cusd

--local text = '+CUSD: 0,"04110430043b0430043d0441003a003200390036002c003000320440", 17r'

-- print(cusd:match(text))
