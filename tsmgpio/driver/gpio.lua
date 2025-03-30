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
	__call = function(gpio, confgpio, state)
		gpio.confgpio = confgpio
		gpio.state = state
		
		gpio:init()
		gpio.state:init(gpio, confgpio)

		gpio.state:make_ubus()

		uloop.run()

		return gpio
	end
}

setmetatable(gpio, metatable)

return gpio
