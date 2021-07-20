require "ubus"

--local log = require "util.log"
local uloop = require("uloop")

uloop.init()

-- Establish connection
local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubusd")
end

local timer1
local timer2
function t1()
    --print("1000 ms timer run");
    local status = conn:call("tsmodem.driver", "reg", { })

    timer1:set(2000)
end
timer1 = uloop.timer(t1)
timer1:set(1000)

function t2()
    --print("1000 ms timer run");
    local status = conn:call("tsmodem.driver", "level", { })

    timer2:set(6000)
end
timer2 = uloop.timer(t2)
timer2:set(1000)

-- Close connection
--conn:close()

uloop.run()
conn:close()