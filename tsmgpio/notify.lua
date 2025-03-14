require "ubus"
require "uloop"

uloop.init()

local conn = ubus.connect()
if not conn then
	error("Failed to connect to ubus")
end

local resp = {
	value = "0",
	direction = "in",
	trigger = "rise",
}

notify_data = {
	gpio = "io0",
	value = "1",
	direction = "out",
	trigger = "none",		
}

local ubus_objects = {
 	tsm_gpio = {
 		io0 = {
 			function(req, msg)
 				conn:reply(req, resp);
 			end, {id = ubus.INT32, msg = ubus.STRING }
 		},
	}
}

conn:add( ubus_objects )
print("Objects added, starting loop")

-- start time
local timer
function t()
	conn:notify( ubus_objects.tsm_gpio.__ubusobj, "gpio_update", notify_data )
	timer:set(2000)
end

timer = uloop.timer(t)
timer:set(2000)

uloop.run()