local cp2112 = require "driver.gpio_cp2112_driver"
local cp2112_IRQ = require"parser.gpio_cp2112_parser"

local gpio = {}

gpio.device = cp2112
gpio.device_special = cp2112_IRQ

function gpio:init()
	gpio.device:AllGPIO_ToInput()
end

function gpio:ActionOnEvent()
	if(gpio.notifier.gpio_change_detected) then
		print("GPIO Event detected")
		gpio.notifier.gpio_change_detected = false
	end
end

local metatable = {
	__call = function(gpio, confgpio, state, notifier, timer)
		gpio.confgpio = confgpio
		gpio.state = state
		gpio.notifier = notifier
		gpio.timer = timer

		uloop.init()
		
		gpio:init()
		gpio.state:init(gpio, confgpio, notifier, timer)
		gpio.confgpio:init(gpio, state, notifier, timer)
		gpio.notifier:init(gpio, state, confgpio, timer)
		gpio.timer:init(gpio, state, confgpio, notifier)

		gpio.state:make_ubus()
		gpio.notifier:Run()

		uloop.run()

		return gpio
	end
}

setmetatable(gpio, metatable)

return gpio
