local ubus = require "ubus"
local uloop = require "uloop"

local cp2112 = require "gpio_cp2112_driver"
local cp2112_IRQ = require"gpio_cp2112_parser"

local tsmgpio = {}
tsmgpio.conn = nil
tsmgpio.device = cp2112
tsmgpio.device_special = cp2112_IRQ
tsmgpio.ubus_object = nil
tsmgpio.gpio_params	= nil

-- Функция для вывода таблицы для отладки
local function printTable(t, indent)
    indent = indent or 0
    local formatting = string.rep("  ", indent)  -- Форматирование отступов

    for key, value in pairs(t) do
        if type(value) == "table" then
            print(formatting .. tostring(key) .. ":")
            printTable(value, indent + 1)  -- Рекурсивный вызов для вложенной таблицы
        else
            print(formatting .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

function tsmgpio:init()
	tsmgpio.conn = ubus.connect()
	if not tsmgpio.conn then
		error("Failed to connect to ubus")
	end
	-- Все контакты переводим на вход для безопасности "железа".
	tsmgpio.device:AllGPIO_ToInput()
end

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
		return tsmgpio.device:ReadGPIO(io_number)
	end

	tsmgpio.device:SetDirection(msg["direction"], io_number)

	local value
	if msg["direction"] == "in" then
		tsmgpio.device:SetEdge(msg["trigger"], io_number)
		if msg["trigger"] ~= "none" then
			-- Передаем счетчик срабатываний по событию триггера
			value = tsmgpio.device_special:ReadGPIO_IRQ(io_number)
		else
			value = tsmgpio.device:ReadGPIO(io_number)
		end
	else
		-- Принудительный сброс триггера.
		tsmgpio.device:SetEdge("none", io_number)
	end
	if msg["direction"] == "out" then
		-- Если поле "value" некорректное - принудительно
		--  устанавливаем порт в режим "in" для безопасности железа
		if msg["value"] ~= "0" and msg["value"] ~= "1" then
			tsmgpio.device:SetDirection("in", io_number)
		else
			-- Устанавливаем состояние выхода
			tsmgpio.device:WriteGPIO(tonumber(msg["value"]), io_number)
		end
		value = tsmgpio.device:ReadGPIO(io_number)
	end
	return value
end

-- Чтение всех портов и запись данных в UBUS
local function GPIO_Scan()
    local gpio_scan_list = {}  
    for i = 0, 7 do
        local ioPin = "IO" .. i  
        gpio_scan_list[ioPin] = {}  
        
        local direction = tsmgpio.device:GetDirection(tsmgpio.device[ioPin])
        local edge = tsmgpio.device:GetEdge(tsmgpio.device[ioPin])

        if direction then
            gpio_scan_list[ioPin]["direction"] = direction
        else
            print("Warning: direction for " .. ioPin .. " is nil")
        end
        
        if edge then
            gpio_scan_list[ioPin]["edge"] = edge
        else
            print("Warning: edge for " .. ioPin .. " is nil")
        end

        if gpio_scan_list[ioPin]["direction"] == "in" and (gpio_scan_list[ioPin]["edge"] ~= "none") then
            gpio_scan_list[ioPin]["value"] = tsmgpio.device_special:ReadGPIO_IRQ(tsmgpio.device[ioPin])
        else
            gpio_scan_list[ioPin]["value"] = tsmgpio.device:ReadGPIO(tsmgpio.device[ioPin])
        end
    end
    return gpio_scan_list
end

function tsmgpio:make_ubus()
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
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO0)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO0)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO0)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO1 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO1)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO1)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO1)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO2 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO2)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO2)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO2)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO3 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO3)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO3)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO3)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO4 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO4)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO4)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO4)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO5 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO5)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO5)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO5)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO6 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO6)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO6)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO6)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},
 			IO7 = {
 				function(req, msg)
 					resp["response"]["value"] = GPIO_DataUpdate(msg, tsmgpio.device.IO7)
 					resp["response"]["direction"] = tsmgpio.device:GetDirection(tsmgpio.device.IO7)
 					resp["response"]["trigger"] = tsmgpio.device:GetEdge(tsmgpio.device.IO7)
 					tsmgpio.conn:reply(req, resp)
				end, gpio_params
			},						
		}
	}

	tsmgpio.ubus_object = ubus_objects
	tsmgpio.gpio_params = gpio_params
	-- Регистрация объекта в UBUS
	tsmgpio.conn:add(tsmgpio.ubus_object)
end



function tsmgpio:poll()
 	local timer
 	function t()
 		-- Получаем результаты сканирования GPIO
		local gpio_scan_resault = GPIO_Scan()
		-- Отправка данных подписчикам
		tsmgpio.conn:notify(tsmgpio.ubus_object["tsmodem.gpio"].__ubusobj, "tsmodem.gpio", gpio_scan_resault)
		timer:set(2000)
	end
	timer = uloop.timer(t)
	timer:set(1000)
end

tsmgpio:init()
uloop.init()
tsmgpio:make_ubus()
--tsmgpio:poll()
uloop.run()
