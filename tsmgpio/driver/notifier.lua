local cp2112 = require "tsmgpio.driver.gpio_cp2112_driver"
local cp2112_IRQ = require"tsmgpio.parser.gpio_cp2112_parser"

local notifier = {}

notifier.tsmgpio = nil
notifier.state = nil
notifier.configurator = nil

notifier.init = function(tsmgpio, state, configurator)
    notifier.tsmgpio = tsmgpio
    notifier.state = state
    notifier.configurator = configurator
    print("notifier.init() OK")
    return notifier
end



--****************** Вынести в ../util/ ************************************************
local previous_gpio_states = {}  -- Хранит предыдущее состояние портов
-- Чтение всех портов и запись данных в UBUS
local function GPIO_Scan()
	local gpio_scan_list = {}  -- Список для хранения текущего состояния GPIO портов
	local has_changes = false   -- Логическая переменная для отслеживания изменений
    -- Проходим по всем портам от 0 до 7
    for i = 0, 7 do
    	local ioPin = "IO" .. i  -- Формируем имя порта, например IO0, IO1 и т.д.
    	gpio_scan_list[ioPin] = {}  -- Инициализируем новый элемент в списке для текущего порта
    	-- Получаем направление и триггер
    	local direction = state.device:GetDirection(state.device[ioPin])
    	local edge = state.device:GetEdge(state.device[ioPin])
    	-- Проверяем и записываем направление
    	if direction then
    		gpio_scan_list[ioPin]["direction"] = direction
    	else
    		print("Warning: direction for " .. ioPin .. " is nil")
    	end     
    	-- Проверяем и записываем триггер
    	if edge then
    		gpio_scan_list[ioPin]["edge"] = edge
    	else
    		print("Warning: edge for " .. ioPin .. " is nil")
    	end
    	-- Читаем значение порта в зависимости от его направления и триггера
    	if gpio_scan_list[ioPin]["direction"] == "in" and (gpio_scan_list[ioPin]["edge"] ~= "none") then
    		gpio_scan_list[ioPin]["value"] = state.device_special:ReadGPIO_IRQ(state.device[ioPin])
    	else
    		gpio_scan_list[ioPin]["value"] = state.device:ReadGPIO(state.device[ioPin])
    	end
    	-- Проверяем, изменилось ли состояние порта по сравнению с предыдущим
    	if not previous_gpio_states[ioPin] or 
    			previous_gpio_states[ioPin]["value"] ~= gpio_scan_list[ioPin]["value"] or 
    			previous_gpio_states[ioPin]["direction"] ~= gpio_scan_list[ioPin]["direction"] or 
    			previous_gpio_states[ioPin]["edge"] ~= gpio_scan_list[ioPin]["edge"] then
    		-- Если состояние изменилось, сохраняем текущее состояние
    		previous_gpio_states[ioPin] = {
    			value = gpio_scan_list[ioPin]["value"],
    			direction = gpio_scan_list[ioPin]["direction"],
    			edge = gpio_scan_list[ioPin]["edge"]
    		}
    		has_changes = true  -- Устанавливаем флаг изменений
    	end
    end    
    -- Возвращаем все порты и логическую переменную has_changes
    return gpio_scan_list, has_changes  
end
-- *********************************************************************************************************

return notifier