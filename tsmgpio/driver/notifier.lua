local notifier = {}

notifier.gpio = nil
notifier.state = nil
notifier.confgpio = nil
notifier.gpio_scan_result = nil
notifier.gpio_change_detected = false

function notifier:init(gpio, state, confgpio)
	notifier.gpio = gpio
	notifier.state = state
	notifier.confgpio = confgpio
	return notifier
end

local previous_gpio_states = {}  -- Хранит предыдущее состояние портов

local function GPIO_Scan()
    local changed_gpio_list = {}  -- Список для хранения только измененных состояний GPIO
    local has_changes = false     -- Логическая переменная для отслеживания изменений
    -- Проходим по всем портам от 0 до 7
    for i = 0, 7 do
        local ioPin = "IO" .. i  -- Формируем имя порта, например IO0, IO1 и т.д.
        local current_state = {}  -- Текущее состояние порта
        -- Получаем направление и триггер
        local direction = notifier.gpio.device:GetDirection(notifier.gpio.device[ioPin])
        local edge = notifier.gpio.device:GetEdge(notifier.gpio.device[ioPin])
        -- Проверяем и записываем направление
        if direction then
            current_state["direction"] = direction
        else
            error("Warning: direction for " .. ioPin .. " is nil")
        end     
        -- Проверяем и записываем триггер
        if edge then
            current_state["edge"] = edge
        else
            error("Warning: edge for " .. ioPin .. " is nil")
        end
        -- Читаем значение порта в зависимости от его направления и триггера
        if current_state["direction"] == "in" and (current_state["edge"] ~= "none") then
            current_state["value"] = notifier.gpio.device_special:ReadGPIO_IRQ(notifier.gpio.device[ioPin])
        else
            current_state["value"] = notifier.gpio.device:ReadGPIO(notifier.gpio.device[ioPin])
        end
        -- Проверяем, изменилось ли состояние порта по сравнению с предыдущим
        if not previous_gpio_states[ioPin] or 
           previous_gpio_states[ioPin]["value"] ~= current_state["value"] or 
           previous_gpio_states[ioPin]["direction"] ~= current_state["direction"] or 
           previous_gpio_states[ioPin]["edge"] ~= current_state["edge"] then
            -- Если состояние изменилось, сохраняем текущее состояние
            previous_gpio_states[ioPin] = {
                value = current_state["value"],
                direction = current_state["direction"],
                edge = current_state["edge"]
            }
            -- Добавляем только измененный порт в результирующую таблицу
            changed_gpio_list[ioPin] = {
                value = current_state["value"],
                direction = current_state["direction"],
                edge = current_state["edge"]
            }
            has_changes = true  -- Устанавливаем флаг изменений
        end
    end    
    -- Возвращаем только измененные порты и логическую переменную has_changes
    return changed_gpio_list, has_changes  
end

function notifier:Run()
    -- Получаем результаты сканирования GPIO
    local has_changes
	notifier.gpio_scan_result, has_changes = GPIO_Scan()
	if has_changes then
		notifier.state.conn:notify(notifier.state.ubus_object["tsmodem.gpio"].__ubusobj, 
			"tsmodem.gpio_update", notifier.gpio_scan_result) 
		notifier.gpio_change_detected = has_changes -- Передаем событие в другой модуль
        has_changes = false
		--print("Данные по GPIO обновлены: notify()")
	end
end


return notifier