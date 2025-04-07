local uci = require "luci.model.uci".cursor()
local config_file = "tsmgpio"
local section_type = "gpio"

local confgpio = {}

confgpio.gpio = nil
confgpio.state = nil
confgpio.gpio_config_cache = {}

-- Функция для чтения всех конфигураций GPIO в таблицу
function confgpio:GetGPIOconfig()
    -- Получаем все секции с именем 'gpio'
    uci:foreach(config_file, section_type, function(section)
        local section_name = section[".name"]
        confgpio.gpio_config_cache[section_name] = {}
        -- Копируем все параметры секции в таблицу
        for key, value in pairs(section) do
            if not key:match("^%.") then -- Игнорируем служебные поля (начинающиеся с точки)
                confgpio.gpio_config_cache[section_name][key] = value
            end
        end
    end)
end

local function SetGPIOconfig(gpio, config)
    for section_name, section_data in pairs(config) do
        -- Обрабатываем только секции вида "IO_*" с status == "enable"
        if section_name:match("^IO") and section_data.status == "enable" then
        	-- Применяем настройки из файла к линиям ввода вывода
        	gpio.device:SetDirection(section_data.direction, gpio.device[section_name])
        	if section_data.direction == "out" then
        		gpio.device:WriteGPIO(tonumber(section_data.value), gpio.device[section_name])
        	else
        		gpio.device:SetEdge(section_data.trigger, gpio.device[section_name])
            end
        end
    end
end

function confgpio:init(gpio, state, notifier)
    confgpio.gpio = gpio
    confgpio.state = state
    confgpio.notifier = notifier
    -- Чтение конфигурации GPIO
    confgpio:GetGPIOconfig()
	-- Применение конфигурации
	if confgpio.gpio_config_cache["general"]["isActive"] == "true" then
		SetGPIOconfig(confgpio.gpio, confgpio.gpio_config_cache)
	end
    
    print("confgpio.init() OK")
	return confgpio
end

return confgpio
