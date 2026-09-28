local U = require 'posix.unistd'

local clear_sms_storage = {}

function clear_sms_storage.clear(modem)
    U.write(modem.fds, "AT+CMGF=1;+CMGD=1,4" .. "\r\n")
    if_debug("send_at", "AT SEND +CMGD: delete all SMS")
    if_debug("send_at", "----------------------")
end

return clear_sms_storage