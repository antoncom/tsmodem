local cp2112 = require "driver.gpio_cp2112_driver"
local cp2112_IRQ = require "parser.gpio_cp2112_parser"

local util = require "luci.util"
local gpio = {}

gpio.device = cp2112
gpio.device_special = cp2112_IRQ

function gpio:init()
	gpio.device:AllGPIO_ToInput()
end

function gpio:ActionOnEvent()
	if(gpio.notifier.gpio_change_detected) then
		-- Обновление данных по конфигурации
		-- TODO: выполнять чтение только если MD5sum 
		-- конфига отличается
		gpio.confgpio:GetGPIOconfig()
		print("***********GPIO Event detected**********")
		util.dumptable(gpio.notifier.gpio_scan_result)
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
		gpio.state:make_ubus()
		gpio.confgpio:init(gpio, state, notifier, timer)
		gpio.notifier:init(gpio, state, confgpio, timer)
		gpio.timer:init(gpio, state, confgpio, notifier)

		gpio.notifier:Run()

		uloop.run()

		return gpio
	end
}

setmetatable(gpio, metatable)

return gpio
