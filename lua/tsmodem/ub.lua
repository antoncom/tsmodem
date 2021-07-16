require "ubus"

--local log = require "util.log"
local uloop = require("uloop")

uloop.init()

-- Establish connection
local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local timer
function t()
    --print("1000 ms timer run");
    local status = conn:call("tsmodem", "level", { })

    timer:set(2000)
end
timer = uloop.timer(t)
timer:set(1000)

-- Close connection
--conn:close()

uloop.run()
conn:close()