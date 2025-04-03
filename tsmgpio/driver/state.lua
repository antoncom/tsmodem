local ubus = require "ubus"
require "uloop"

local data_util = require "util.data_utillity"

local state = {}

state.conn = nil
state.ubus_object = nil
state.gpio_params = nil

function state:init(gpio, confgpio, notifier)
	state.gpio = gpio
	state.confgpio = confgpio
	state.notifier = notifier
	--  Попытка установить соединение с ubus
    state.conn = ubus.connect()
	if not state.conn then
		-- TODO: Заменить на if_debug()
		error("gpio.state: Failed to connect to ubus")
	end
	print("state init: OK")
end

-- Запись данных из UBUS в GPIO c защитой от некорректных запросов
function GPIO_DataUpdate(msg, io_number)
	if not data_util:UbusValidateInputData(msg) then
		return state.gpio.device:ReadGPIO(io_number)
	end

	state.gpio.device:SetDirection(msg["direction"], io_number)

	local value
	if msg["direction"] == "in" then
		state.gpio.device:SetEdge(msg["trigger"], io_number)
		if msg["trigger"] ~= "none" then
			-- Передаем счетчик срабатываний по событию триггера
			value = state.gpio.device_special:ReadGPIO_IRQ(io_number)
		else
			value = state.gpio.device:ReadGPIO(io_number)
		end
	else
		-- Принудительный сброс триггера.
		state.gpio.device:SetEdge("none", io_number)
	end
	if msg["direction"] == "out" then
		-- Если поле "value" некорректное - принудительно
		--  устанавливаем порт в режим "in" для безопасности железа
		if msg["value"] ~= "0" and msg["value"] ~= "1" then
			state.gpio.device:SetDirection("in", io_number)
		else
			-- Устанавливаем состояние выхода
			state.gpio.device:WriteGPIO(tonumber(msg["value"]), io_number)
		end
		value = state.gpio.device:ReadGPIO(io_number)
	end
	return value
end

function state:make_ubus()
	-- Таблица параметров GPIO для драйвера
    -- TODO: надо как-то объеденить эти таблицы в одну
    local gpio_params = {
        direction 	= ubus.STRING,   
        value 		= ubus.STRING,                 
        trigger 	= ubus.STRING,            
    }
    local resp = {
		["response"] = {
			value = "",
			direction = "",
			trigger = "",
		}
	}

	-- Создание UBUS объекта для управления портами
	-- TODO: Придумать, как сгенерировать объект в цикле на N число портов.
 	local ubus_objects = {
 		["tsmodem.gpio"] = {
 			IO0 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO0)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO0)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO0)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO1 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO1)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO1)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO1)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO2 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO2)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO2)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO2)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO3 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO3)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO3)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO3)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO4 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO4)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO4)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO4)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO5 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO5)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO5)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO5)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO6 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO6)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO6)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO6)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO7 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.gpio.device.IO7)
 					resp["response"]["direction"] = state.gpio.device:GetDirection(state.gpio.device.IO7)
 					resp["response"]["trigger"] = state.gpio.device:GetEdge(state.gpio.device.IO7)
 					state.conn:reply(req, resp)
				end, gpio_params
			},						
		}
	}
	state.ubus_object = ubus_objects
	state.gpio_params = gpio_params
	-- Регистрация объекта в UBUS
	state.conn:add(state.ubus_object)
end

return state
