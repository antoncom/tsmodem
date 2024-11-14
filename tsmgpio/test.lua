local cp2112 = require "gpio"

local tsmgpio = {}
tsmgpio.conn = nil
tsmgpio.device = cp2112
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
            gpio_scan_list[ioPin]["value"] = tsmgpio.device:ReadGPIO_IRQ(tsmgpio.device[ioPin])
        else
            gpio_scan_list[ioPin]["value"] = tsmgpio.device:ReadGPIO(tsmgpio.device[ioPin])
        end
    end
    return gpio_scan_list
end

-- Создание UBUS объекта
local ubus_objects = {
    ["tsmodem.gpio"] = {}
}

-- Получаем результаты сканирования GPIO
local gpio_results = GPIO_Scan()

-- Добавляем результаты в UBUS объект
for pin, data in pairs(gpio_results) do
    if data then  -- Проверка на nil перед добавлением в ubus_objects
        ubus_objects["tsmodem.gpio"][pin] = data
    else
        print("Warning: data for " .. pin .. " is nil")
    end
end

printTable(ubus_objects)