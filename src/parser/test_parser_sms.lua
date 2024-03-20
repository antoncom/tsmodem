parser = require "parser_sms"
local at = '+CMTI: "SM",2'
local sms_text = "AT+CMGR=1\n\n+CMGR: \"REC READ\",\"+79996661322\",\"\",\"24/02/26,09:47:47+12\"\nbash: applogic restart"

print(parser:get_sms_count(at))
