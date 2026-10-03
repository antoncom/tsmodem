local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


local spc = lpeg.S(" \t\n\r")^0
local d = lpeg.R('09')
local creg = spc * lpeg.P('AT+CREG?')^-1 * spc
           * lpeg.P('+CREG: ') * (d * ',')^-1 * lpeg.C(d)
return creg
