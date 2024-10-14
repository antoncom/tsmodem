local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


local spc = lpeg.S(" \t\n\r")^0
local num = lpeg.S("0123456789")^1

function remove_control_chars(chunk)
	return chunk:gsub("%c+", " ")
end

local cmgs_ok = spc * lpeg.C(lpeg.P('+CMGS:') * spc * num * spc * lpeg.P("OK")^0) / remove_control_chars

return cmgs_ok

-- Тесты
--local chunk = [[+CMGS: 92]]
--local chunk = [[ +CMGS: 153 OK]]
--local res = cmgs_ok:match(chunk)
--print(res)



