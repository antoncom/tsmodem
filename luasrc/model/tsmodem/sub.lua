

require "ubus"
require "uloop"

local log = require "luci.model.tsmodem.util.log"


lpeg = require 'lpeg'

CSQ = lpeg.P("\r\n")^0 * lpeg.P('+CSQ: ') *
       lpeg.C(lpeg.R('09')^-2) *
       lpeg.P(',')^-1 *
       lpeg.C(lpeg.R('09')^-2)

uloop.init()

local conn = ubus.connect()
if not conn then
	error("Failed to connect to ubus")
end

local sub = {
	notify = function(msg, name)
		print("Name: ", name)
		print("Message: ", msg["message"])
		local rssi, bor = CSQ:match(msg["message"])
		print("rssi, bor", rssi, bor)
		if(rssi == "99") then
			print("RSSI=99 needs switch sim")
			conn:call("tsmodem.driver", "switch", { })
		end
	end,
}


conn:subscribe("tsmodem.rule", {
	notify = function(msg, name)
		print("Event", name)
		log("data", msg)
	end
})

-- this is the call that does the subscribing
-- conn:subscribe("tsmodem.driver", sub)


uloop.run()
conn:close()


