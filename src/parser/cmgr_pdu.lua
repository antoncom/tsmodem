local lpeg = require("lpeg")

local hex_digit = lpeg.R("09", "af", "AF")
local pdu_data_string = lpeg.C(hex_digit^10)

local cmgr_pdu = lpeg.P({
    "search",
    search = pdu_data_string + (lpeg.P(1) * lpeg.V("search"))
})

return cmgr_pdu


-- local util = require("luci.util")
-- local pdu_decoder = require 'tsmodem.util.pdu_decoder'
-- local chunk = "+CMGR: 0,,44 07919732520111F20406810010000008627032318534821C04110430043B0430043D04410020003500380031002E003200200440 OK"
-- local pdu_data = cmgr_pdu:match(chunk)
-- local sms_data = pdu_decoder.parse(pdu_data)
-- print(pdu_data)
-- print(util.dumptable(sms_data))
