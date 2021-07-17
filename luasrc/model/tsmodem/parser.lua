local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0

-- +CREG: 1,04B5,01E88901
local creg = spc * lpeg.P('+CREG: ') *
       	(lpeg.C(lpeg.R('02')) * lpeg.P(',')^-1)^-1 *
		lpeg.C(lpeg.R('05')) *
       	lpeg.P(',')^-1 *
       	lpeg.C(lpeg.R("af", "AF", "09")^-4) *
       	lpeg.P(',')^-1 *
       	lpeg.C(lpeg.R("af", "AF", "09")^-8)

local at = {
	CREG = 	creg
}

return at
