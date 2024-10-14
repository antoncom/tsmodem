local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


local spc = lpeg.S(" \t\n\r")^0
local num = lpeg.S("012345678")^1


local cmgs = spc * lpeg.C(lpeg.P('+CMGS:') * spc * num) * spc

--return cmgs

-- Тесты
local chunk = "CMGS: 37"
print(cmgs:match(chunk))



