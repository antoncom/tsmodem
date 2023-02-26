local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


local spc = lpeg.S(" \t\n\r")^0
local mixed = lpeg.R("az", "AZ", "09", ":@", "[_", "(+")^1

local pname = spc * lpeg.P('+NITZ: PLMN Long Name: ') *
		lpeg.C(mixed) * "," * spc

return pname

--local text = "+NITZ: PLMN Long Name: MegaPhone,"

--print(text)
--print(pname:match(text))
