local cp2112 = require "driver.gpio_cp2112_driver"
local cp2112_IRQ = require"parser.gpio_cp2112_parser"

local gpio = {}

gpio.device = cp2112
gpio.device_special = cp2112_IRQ

function gpio:init()
	gpio.device:AllGPIO_ToInput()
	print("gpio:init() OK")
end

local metatable = {
	__call = function(gpio, confgpio, state, notifier)
		gpio.confgpio = confgpio
		gpio.state = state
		gpio.notifier = notifier

		uloop.init()
		
		gpio:init()
		gpio.state:init(gpio, confgpio, notifier)
		gpio.confgpio:init(gpio, state, notifier)
		gpio.notifier:init(gpio, state, confgpio)

		gpio.state:make_ubus()
		gpio.notifier:run()

		uloop.run()

		return gpio
	end
}

setmetatable(gpio, metatable)

return gpio
