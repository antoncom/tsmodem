local uci = require "luci.model.uci".cursor()
local nixio = require "nixio"
-- TODO: Вынести это в отдельный модуль
local config_file = "tsmgpio"
local config_path = "/etc/config/" .. config_file
local section_type = "gpio"

local confgpio = {}

confgpio.gpio = nil
confgpio.state = nil
confgpio.gpio_config_cache = {}

local fs = nixio.fs

function CheckConfigUpdate()
    local file_stat = fs.stat(config_path)
    if not file_stat then
        return false  -- Файл не существует (или ошибка доступа)
    end
    local current_mtime = file_stat.mtime
    if current_mtime ~= last_mtime then
        last_mtime = current_mtime  -- Обновляем состояние
        return true  -- Файл изменён
    end
    return false  -- Изменений нет
end

-- Функция для чтения всех конфигураций GPIO в таблицу
function confgpio:GetGPIOconfig()
    if CheckConfigUpdate() then
        --print("Конфиг изменился! Читаем файл...")
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
    else
        --print("Конфиг не менялся.")
    end 
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
