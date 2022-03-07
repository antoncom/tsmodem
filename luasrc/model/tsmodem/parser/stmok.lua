local lpeg = require "lpeg"
local log = require "luci.model.tsmodem.util.log"


spc = lpeg.S(" \t\n\r")^0

local stmok = spc * lpeg.C(lpeg.P('OK')) * spc

return stmok



