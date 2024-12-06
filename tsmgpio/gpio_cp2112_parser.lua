local ParserGPIO = {}

function ParserGPIO:ReadGPIO_IRQ(id)
    local IO = id - 408
    local IO_IRQ
    -- Выполняем команду и открываем поток для чтения
    local handle = io.popen("cat /proc/interrupts | grep cp2112-gpio")
    local result = handle:read("*a")  -- Читаем весь вывод команды
    handle:close()  -- Закрываем поток
    -- Парсим вывод
    for line in result:gmatch("[^\n]+") do
        -- Проверяем, содержит ли строка номер IO
        if line:find(IO .. "%s+%sgpiolib") then
            -- Извлекаем количество прерываний (число перед "cp2112-gpio")
            local irq_count = line:match("(%d+)%s+cp2112%-gpio%s+" .. IO)
            if irq_count then
                IO_IRQ = tonumber(irq_count)
                --print("IO_IRQ найден:", IO_IRQ)  -- Отладочный вывод
            end
        end
    end
    return IO_IRQ  -- Возвращаем найденное значение
end

return ParserGPIO  -- Возвращаем таблицу с функциями
