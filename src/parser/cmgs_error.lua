local lpeg = require "lpeg"
local log = require "tsmodem.util.log"


local spc = lpeg.S(" \t\n\r\\26\\u001a")^0
local num = lpeg.S("0123456789")^1
local pdumsg = lpeg.S("0123456789ABCDEF")^0
local ctrlZ = lpeg.P("\\u001a")^0 + lpeg.P("\26")^0

function remove_control_chars(chunk)
	return chunk:gsub("%c+", " ")
end


local cmgs_error = spc * pdumsg * ctrlZ * spc * lpeg.C(lpeg.P('+CMS ERROR:')^1 * spc * num * spc) / remove_control_chars

return cmgs_error

-- Тесты
--local chunk = [[+CMS ERROR: 55]]
--local chunk = [[0011000C919730507071F500080B18006400730064007300640020007300640073006400730064\26    +CMS ERROR: 332]]
--local chunk = [[0011000C919730507071F500080B18006400730064007300640020007300640073006400730064\u001a    +CMS ERROR: 332]]
--local res = cmgs_error:match(chunk)
--print(res)



