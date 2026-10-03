local lpeg = require "lpeg"
local log = require "tsmodem.util.log"

local cnsmod = spc * lpeg.P('+CNSMOD: ') * (lpeg.R('01') * ',')^-1 * lpeg.C(lpeg.R('09')^1)

return cnsmod


