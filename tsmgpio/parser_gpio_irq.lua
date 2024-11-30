local IO0_IRQ, IO1_IRQ, IO2_IRQ

-- Выполняем команду и открываем поток для чтения
local handle = io.popen("cat /proc/interrupts | grep cp2112-gpio")
local result = handle:read("*a")  -- Читаем весь вывод команды
handle:close()  -- Закрываем поток

-- Парсим вывод
for line in result:gmatch("[^\n]+") do
    print("Строка:", line)  -- Отладочный вывод строки

    -- Проверяем, содержит ли строка номер 5
    if line:find("5") then
        -- Извлекаем количество прерываний (число перед "cp2112-gpio")
        local irq_count = line:match("(%d+)%s+cp2112%-gpio%s+5")
        if irq_count then
            IO0_IRQ = tonumber(irq_count)
            print("IO0_IRQ найден:", IO0_IRQ)  -- Отладочный вывод
        end
    end
    
    -- Проверяем, содержит ли строка номер 6
    if line:find("6") then
        local irq_count = line:match("(%d+)%s+cp2112%-gpio%s+6")
        if irq_count then
            IO1_IRQ = tonumber(irq_count)
            print("IO1_IRQ найден:", IO1_IRQ)  -- Отладочный вывод
        end
    end
    
    -- Проверяем, содержит ли строка номер 7
    if line:find("7") then
        local irq_count = line:match("(%d+)%s+cp2112%-gpio%s+7")
        if irq_count then
            IO2_IRQ = tonumber(irq_count)
            print("IO2_IRQ найден:", IO2_IRQ)  -- Отладочный вывод
        end
    end
end

-- Выводим значения
print("IO0_IRQ =", IO0_IRQ)
print("IO1_IRQ =", IO1_IRQ)
print("IO2_IRQ =", IO2_IRQ)
