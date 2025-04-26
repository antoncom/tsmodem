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

-- Проверка даты изменения файла конфига
-- чтобы не загружать ЦП постоянными операциями чтения.
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
    print("Конфиг изменился! Читаем файл...")
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
        -- Обрабатываем только секции вида "IO*" с status == "enable"
        if section_name:match("^IO") and section_data.status == "enable" then
            -- TODO: перенести эти преобразования в драйвер "driver.gpio_cp2112_driver"
            -- Преобразование формата конфига к формату драйвера(IN->in...)
            local direction
            if section_data.direction then
                direction = section_data.direction:lower()
            end            
            -- Применяем настройки направления
            gpio.device:SetDirection(direction, gpio.device[section_name])        
            if direction == "out" then
                -- Значение для вывода (по умолчанию 0)
                local value
                if section_data.value then
                    if section_data.value == "HI" then
                        value = 1
                    elseif section_data.value == "LOW" then
                        value = 0
                    else
                        -- Если значение не "HI" и не "LOW", попробуем преобразовать в число
                        value = tonumber(section_data.value) or 0
                    end
                end
                gpio.device:WriteGPIO(value, gpio.device[section_name])
                -- Тип триггера (по умолчанию 'none' - отключено)
                local trigger
                if section_data.trigger then
                    trigger = section_data.trigger:lower()  -- приводим к нижнему регистру
                    -- Конвертируем сокращенные формы и проверяем допустимые значения
                    if trigger == 'rise' then
                        trigger = 'rising'
                    elseif trigger == 'fall' then
                        trigger = 'falling'
                    elseif trigger ~= 'none' and trigger ~= 'rising' and trigger ~= 'falling' and trigger ~= 'both' then
                        -- Если значение недопустимое, используем 'none'
                        trigger = 'none'
                    end
                end
                gpio.device:SetEdge(trigger, gpio.device[section_name])
            end
        end
    end
end

function confgpio:UpdateGPIO_InConfig()
    if CheckConfigUpdate() then
        -- Чтение конфигурации GPIO
        confgpio:GetGPIOconfig()
        -- Применение конфигурации
        if confgpio.gpio_config_cache["general"]["isActive"] == "1" then
            SetGPIOconfig(confgpio.gpio, confgpio.gpio_config_cache)
        end
    end
end

function confgpio:init(gpio, state, notifier)
    confgpio.gpio = gpio
    confgpio.state = state
    confgpio.notifier = notifier
    --confgpio:UpdateGPIO_InConfig()
    print("confgpio.init() OK")
	return confgpio
end

return confgpio
