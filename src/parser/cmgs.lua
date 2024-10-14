local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


local spc = lpeg.S(" \t\n\r")^0
local num = lpeg.S("0123456789")^1

function remove_control_chars(chunk)
	return chunk:gsub("%c+", " ")
end


local cmgs = spc * lpeg.C(lpeg.P('+CMGS:') * spc * num * spc * lpeg.P("OK")^1) / remove_control_chars
-- local cmgs = spc * lpeg.C(lpeg.P('+CMGS:') * spc * num * * lpeg.P("OK")^-1) * spc

--return cmgs

-- Тесты
-- local chunk = [[

-- +CMGS: 92


-- ERROR

-- AT+CNSMOD
-- ]]

local chunk = [[+CMGS: 92 OK]]

local res = cmgs:match(chunk)
print(res)



