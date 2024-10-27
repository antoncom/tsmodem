local ubus = require "ubus"
local uloop = require "uloop"

local cp2112_gpio = require "gpio"

local tsmgpio = {}
tsmgpio.conn = nil
tsmgpio.gpio = cp2112_gpio
tsmgpio.ubus_object = nil
tsmgpio.gpio_params	= nil

function tsmgpio:init()
	tsmgpio.conn = ubus.connect()
	if not tsmgpio.conn then
		error("Failed to connect to ubus")
	end
	tsmgpio.gpio:AllGPIO_ToInput()
end

function tsmgpio:make_ubus()
	-- Создание UBUS объекта
 	local ubus_objects = {
 		["tsmodem.gpio"] = {
 			value = {
 				function(req, msg)
 					--conn:reply(req, {message="foo"});
 					print("Call to function 'hello'")
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
		}
	}
	-- Таблица всех параметров GPIO 
    local gpio_params = {
        direction = "input",   
        value = 1,             
        action = "toggle",     
        trigger = "button",     
        debounce = 50           
    }

	tsmgpio.ubus_object = ubus_objects
	tsmgpio.gpio_params = gpio_params

	-- Регистрация объекта в UBUS
	tsmgpio.conn:add(tsmgpio.ubus_object)
end

function tsmgpio:poll()
 	local timer
 	function t()
		ubus:publish(tsmgpio.ubus_object, tsmgpio.gpio_params)
		timer:set(1000)
	end
	timer = uloop.timer(t)
	timer:set(1000)
end



tsmgpio:init()
tsmgpio:poll()
uloop.init()
tsmgpio:make_ubus()
uloop.run()
