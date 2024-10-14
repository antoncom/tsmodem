local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0
local number = lpeg.C(
  lpeg.P('-')^-1 *
  lpeg.R('09')^0 *
  (
	  lpeg.S('.,') *
	  lpeg.R('09')^0
  )^-1 )

local sms_text =  spc * lpeg.P('+CMGR: "REC UNREAD"') * spc *
			lpeg.P(54) * lpeg.C(lpeg.S('0123456789ABCDEF')^4)

return sms_text

--local text = '+CMGR: "REC UNREAD","+79030507175","","24/09/21,18:52:54+16"  log\n\r'

--print(cusd:match(text))
