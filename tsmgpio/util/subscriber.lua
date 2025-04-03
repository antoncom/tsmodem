require "ubus"
require "uloop"
local util = require "luci.util"

-- Функция для вывода таблицы для отладки
--local function printTable(t, indent)
--    indent = indent or 0
--    local formatting = string.rep("  ", indent)  -- Форматирование отступов

--    for key, value in pairs(t) do
--        if type(value) == "table" then
--            print(formatting .. tostring(key) .. ":")
--            printTable(value, indent + 1)  -- Рекурсивный вызов для вложенной таблицы
--        else
--            print(formatting .. tostring(key) .. ": " .. tostring(value))
--        end
--    end
--end

-- Функция для вывода всех ключей таблицы
--local function printTableKeys(t)
--    for key, value in pairs(t) do
--        print("Ключ:", key)
--    end
--end

uloop.init()

local conn = ubus.connect()
if not conn then
	error("Failed to connect to ubus")
end

local sub = {
	notify = function( msg )
		--printTable(msg)
        --printTableKeys(msg)
        util.dumptable(msg)
	end,
}

conn:subscribe( "tsmodem.gpio", sub )

uloop.run()