local ubus = require "ubus"
local uloop = require "uloop"

local cp2112 = require "gpio"

local tsmgpio = {}
tsmgpio.conn = nil
tsmgpio.device = cp2112
tsmgpio.ubus_object = nil
tsmgpio.gpio_params	= nil

function tsmgpio:init()
	tsmgpio.conn = ubus.connect()
	if not tsmgpio.conn then
		error("Failed to connect to ubus")
	end
	tsmgpio.device:AllGPIO_ToInput()
end

-- Функция для вывода таблицы для отладки
local function printTable(t)
    for key, value in pairs(t) do
        print(string.format('"%s"="%s"', key, tostring(value)))
    end
end

-- Проверяем поступившие параметры
local function ValidateInputData(msg)
	local direction_valid =(msg["direction"] == "in" 	or msg["direction"] == "out")
	local trigger_valid = (msg["trigger"] == "none" 	or msg["trigger"] == "rising" or
						msg["trigger"] == "falling" or msg["trigger"] == "both")
    return direction_valid and trigger_valid
end

local function GPIO_DataUpdate(msg, io_number)
	local resp = {}
	if ValidateInputData(msg) then
		tsmgpio.device:SetDirection(msg["direction"], io_number)
		if msg["direction"] == "in" then
			tsmgpio.device:SetEdge(msg["trigger"])
			if not msg["trigger"] == "none" then
				resp["irq_counter"] = tsmgpio.device:ReadGPIO_IRQ(io_number)
			else
				resp["value"] = tsmgpio.device:ReadGPIO(io_number)
			end 
		else
			-- Устанавливаем состояние выхода
			tsmgpio.device:SetValue(msg["value"])
		end
	else
		resp["note"] = "Example: XXX"
	end
 	tsmgpio.conn:reply(req, resp);
end

function tsmgpio:make_ubus()
	-- Таблица всех параметров GPIO 
    local gpio_params = {
        direction = ubus.STRING,   
        value = ubus.STRING,                 
        trigger = ubus.STRING,            
    }
	-- Создание UBUS объекта
 	local ubus_objects = {
 		["tsmodem.gpio"] = {
 			IO0 = {
 				function(req, msg)
 					
				end, gpio_params
			},
		}
	}

	tsmgpio.ubus_object = ubus_objects
	tsmgpio.gpio_params = gpio_params

	-- Регистрация объекта в UBUS
	tsmgpio.conn:add(tsmgpio.ubus_object)
end

local function GPIO_EventDetect(IO)
	-- перебросить детект события в правило
	-- возвращать количество событий по UBUS
end 

function tsmgpio:poll()
 	local timer
 	function t()
 		tsmgpio.gpio_params.value = tsmgpio.device:ReadGPIO(408)
		--ubus:notify(tsmgpio.ubus_object, tsmgpio.gpio_params)
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
