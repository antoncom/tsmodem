local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0
local number = lpeg.C(
  lpeg.P('-')^-1 *
  lpeg.R('09')^0 *
  (
	  lpeg.S('.,') *
	  lpeg.R('09')^0
  )^-1 )

local sms_text =  spc * lpeg.P('+CMGR: 1,"",155') * spc *
			lpeg.P(54) * lpeg.C(lpeg.S('0123456789ABCDEF')^4)

return sms_text

--local text = '+CUSD: 0,"04110430043b0430043d0441003a003200390036002c003000320440", 17r'

-- print(cusd:match(text))
