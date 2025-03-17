local ubus = require "ubus"
local uloop = require "uloop"

local cp2112 = require "gpio_cp2112_driver"
local cp2112_IRQ = require"gpio_cp2112_parser"

local state = {}
state.conn = nil
state.device = cp2112
state.device_special = cp2112_IRQ
state.ubus_object = nil
state.gpio_params	= nil

--****************** Вынести в ../util/ ************************************************
-- Проверяем поступившие параметры
local function ValidateInputData(msg)
	local direction_valid = (msg["direction"] == "in" or msg["direction"] == "out")
	local trigger_valid = true  -- Инициализируем переменную trigger_valid по умолчанию
	-- Проверка режимов прерывания
	if msg["direction"] == "in" then
		trigger_valid = (msg["trigger"] == "none" or msg["trigger"] == "rising" or
                     msg["trigger"] == "falling" or msg["trigger"] == "both")
	end

  return direction_valid and trigger_valid
end

-- Запись проверка корректности данных и запись их из UBUS в GPIO
function GPIO_DataUpdate(msg, io_number)
	if not ValidateInputData(msg) then
		return state.device:ReadGPIO(io_number)
	end

	state.device:SetDirection(msg["direction"], io_number)

	local value
	if msg["direction"] == "in" then
		state.device:SetEdge(msg["trigger"], io_number)
		if msg["trigger"] ~= "none" then
			-- Передаем счетчик срабатываний по событию триггера
			value = state.device_special:ReadGPIO_IRQ(io_number)
		else
			value = state.device:ReadGPIO(io_number)
		end
	else
		-- Принудительный сброс триггера.
		state.device:SetEdge("none", io_number)
	end
	if msg["direction"] == "out" then
		-- Если поле "value" некорректное - принудительно
		--  устанавливаем порт в режим "in" для безопасности железа
		if msg["value"] ~= "0" and msg["value"] ~= "1" then
			state.device:SetDirection("in", io_number)
		else
			-- Устанавливаем состояние выхода
			state.device:WriteGPIO(tonumber(msg["value"]), io_number)
		end
		value = state.device:ReadGPIO(io_number)
	end
	return value
end
-- *******************************************************************************

function state:init()
	state.conn = ubus.connect()
	if not state.conn then
		-- TODO: Дебаг-сообщение об ошибке UBUS
	end
	-- TODO: перебросить в модуль "config"
	-- Все контакты переводим на вход для безопасности "железа".
	--state.device:AllGPIO_ToInput()
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
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO0)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO0)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO0)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO1 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO1)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO1)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO1)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO2 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO2)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO2)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO2)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO3 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO3)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO3)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO3)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO4 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO4)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO4)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO4)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO5 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO5)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO5)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO5)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO6 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO6)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO6)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO6)
 					state.conn:reply(req, resp)
				end, gpio_params
			},
 			IO7 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, state.device.IO7)
 					resp["response"]["direction"] = state.device:GetDirection(state.device.IO7)
 					resp["response"]["trigger"] = state.device:GetEdge(state.device.IO7)
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