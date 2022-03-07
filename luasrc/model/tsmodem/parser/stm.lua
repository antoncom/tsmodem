local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0

local stm = spc * lpeg.C(lpeg.R('01')) * spc *
		lpeg.P('OK') * spc

return stm


