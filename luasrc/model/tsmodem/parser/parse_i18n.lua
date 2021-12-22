--[[
This parser is required in tsmodem_adapter_provider
It makes translation of i18n placeholders in JS-file whem the JS file mis loaded not via "require", but via fs.read()
]]

local lpeg = require"lpeg"
local C, Ct, P, R, S = lpeg.C, lpeg.Ct, lpeg.P, lpeg.R, lpeg.S

local translate = function(x)
    return luci.dispatcher.translate(x)
end

local i18n = (R("09") + R("az") + R("AZ") + S(".;:-+_ \t\n\r/"))^1


local placeholder = P"<%:" * (i18n / translate) * P"%>"
local other = C((1 - placeholder)^0)
local grammar =  Ct(other * (placeholder * other)^0)


function parse_i18n(x)
    return(table.concat(grammar:match(x),""))
end

return parse_i18n
--print(table.concat(grammar:match("tttt <%:Mobile device of distant control%> dhdhdhdh"),""))
