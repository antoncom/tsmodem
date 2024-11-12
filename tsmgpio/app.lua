local ubus = require "ubus"
local uloop = require "uloop"

local cp2112 = require "gpio"

local tsmgpio = {}
tsmgpio.conn = nil
tsmgpio.device = cp2112
tsmgpio.ubus_object = nil
tsmgpio.gpio_params	= nil

-- Функция для вывода таблицы для отладки
local function printTable(t)
    for key, value in pairs(t) do
        print(string.format('"%s"="%s"', key, tostring(value)))
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
	local direction_valid =(msg["direction"] == "in" or msg["direction"] == "out")
	if msg["direction"] == "in" then
		local trigger_valid = (msg["trigger"] == "none" or msg["trigger"] == "rising" or
						msg["trigger"] == "falling" or msg["trigger"] == "both")
	else
		trigger_valid = true
	end
    return direction_valid and trigger_valid
end

function GPIO_DataUpdate(msg, io_number)
	local value
	if ValidateInputData(msg) then
		tsmgpio.device:SetDirection(msg["direction"], io_number)
		if msg["direction"] == "in" then
			tsmgpio.device:SetEdge(msg["trigger"])
			if not msg["trigger"] == "none" then
				-- Передаем счетчик срабатываний по событию триггера
				value = tsmgpio.device:ReadGPIO_IRQ(io_number)
			else
				-- Если триггер не установлен, передаем состояние порта
				value = tsmgpio.device:ReadGPIO(io_number)
			end 
		else
			-- Устанавливаем состояние выхода
			tsmgpio.device:WriteGPIO(tonumber(msg["value"]), io_number)
			-- Считываем текущее состояние выхода
			value = tsmgpio.device:ReadGPIO(io_number)
		end
	else
		value = "The data entered is incorrect"
	end
 	return value
end

function tsmgpio:make_ubus()
	-- Таблица параметров GPIO для драйвера
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

	-- Создание UBUS объекта
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

local function GPIO_Scan()
  local gpio_scan_list = {}  -- Инициализируем таблицу для каждого GPIO
  for i = 0, 7 do  -- Цикл от IO0 до IO7
    local ioPin = "IO" .. i  -- Формируем название порта, например "IO0", "IO1" и т.д. 
    gpio_scan_list[ioPin] = {}  -- Инициализируем таблицу для текущего GPIO
    gpio_scan_list[ioPin]["direction"]  = tsmgpio.device:GetDirection(tsmgpio.device[ioPin])
    gpio_scan_list[ioPin]["edge"]       = tsmgpio.device:GetEdge(tsmgpio.device[ioPin])
    if gpio_scan_list[ioPin]["direction"] == "in" and not gpio_scan_list[ioPin]["edge"] == "none" then
    	gpio_scan_list[ioPin]["value"] = tsmgpio.device:ReadGPIO_IRQ(tsmgpio.device[ioPin])
    else
    	gpio_scan_list[ioPin]["value"] = tsmgpio.device:ReadGPIO(tsmgpio.device[ioPin])
    end

  end
  return gpio_scan_list
end

function tsmgpio:poll()
	local gpio_scan_list_ubus
 	local timer
 	function t()
 		gpio_scan_list_ubus = GPIO_Scan()
 		print("gpio scan")
		ubus:notify(tsmgpio.ubus_object, gpio_scan_list_ubus)
		timer:set(1000)
	end
	timer = uloop.timer(t)
	timer:set(1000)
end

tsmgpio:init()
uloop.init()
tsmgpio:make_ubus()
tsmgpio:poll()
uloop.run()
