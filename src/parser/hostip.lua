local lpeg = require "lpeg"
local log = require "tsmodem.util.log"

local v = lpeg.V
local c = lpeg.C

local grammar = {
    "message",      -- Initial rule
    DOT         = lpeg.P("."),
    DASH        = lpeg.P("-"),
    USCORE      = lpeg.P("_"),
    LETTER      = lpeg.R("az", "AZ"),
    DIGIT       = lpeg.R("09"),
    triple      = v"DIGIT" * (v"DIGIT"^-1) * (v"DIGIT"^-1),
    ip4addr     = v"triple" * v"DOT" * v"triple" * v"DOT" * v"triple" * v"DOT" * v"triple",
    shortname   = (v"LETTER" + v"DIGIT") * (v"LETTER" + v"DIGIT" + v"DASH" + v"USCORE")^0 * (v"LETTER" + v"DIGIT")^0,
    hostname    = v"shortname" * (v"DOT" * v"shortname")^1,
    hostaddr    = v"ip4addr",
    host        = v"hostname" + v"hostaddr"
}

function hostip(dtype, value)
    grammar[1] = dtype
    return lpeg.match(grammar, value)
end


return hostip

--local text = "1.1"
--print(hostip("hostname", "s.com"))
