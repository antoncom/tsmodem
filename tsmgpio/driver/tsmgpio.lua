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
	print("tsmgpio:init() OK")
end

function tsmgpio:poll()
 	local timer
 	function t()
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

		tsmgpio.state:init(tsmgpio, notifier, configurator)
		tsmgpio.notifier:init(tsmgpio, state, configurator)
		tsmgpio.configurator:init(tsmgpio, state, notifier)
	
		--uloop.init()
		--uloop.run()
		return tsmgpio
	end
}

setmetatable(tsmgpio, metatable)

return tsmgpio