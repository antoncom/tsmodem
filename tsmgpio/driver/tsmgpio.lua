local ubus = require "ubus"
local uloop = require "uloop"

local tsmgpio = {}

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

function tsmgpio:init()
-- Инициализация всех модулей
end

function tsmgpio:poll()
 	local timer
 	function t()
		-- Получаем результаты сканирования GPIO
		local gpio_scan_result, has_changes = GPIO_Scan()
		--print("*************Таймер 2 сек*****************")
		if has_changes then
			--tsmgpio.conn:notify(tsmgpio.ubus_object["tsmodem.gpio"].__ubusobj, "tsmodem.gpio.update", gpio_scan_result)
			has_changes = false
			print("Данные по GPIO обновлены: notify()")
		end
		--printTable(gpio_scan_result)
		timer:set(2000)
	end
	timer = uloop.timer(t)
	timer:set(2000)
end


-- [[ Initialize ]]
local metatable = {
	__call = function(state, notifier, configurator)
	tsmgpio.state = state
	tsmgpio.notifier = notifier
	tsmgpio.configurator = configurator

	--tsmgpio:init()
	--uloop.init()
	--tsmgpio:make_ubus()
	--tsmgpio:poll()
	--uloop.run()v
}

setmetatable(tsmgpio, metatable)

return tsmgpio