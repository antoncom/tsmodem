local cp2112 = require "driver.gpio_cp2112_driver"
local cp2112_IRQ = require "parser.gpio_cp2112_parser"

local util = require "luci.util"
local gpio = {}

gpio.device = cp2112
gpio.device_special = cp2112_IRQ

function gpio:init()
	gpio.device:AllGPIO_ToInput()
end

function gpio:ActionOnEvent()
    if gpio.notifier.gpio_change_detected then
        -- Обновление данных по конфигурации
        gpio.confgpio:GetGPIOconfig()
        print("***********GPIO Event detected**********")
        -- Проходим по всем изменившимся GPIO
        for io_name, io_data in pairs(gpio.notifier.gpio_scan_result) do
            if io_data.direction == "in" then
                -- Используем имя в формате "IO0", "IO1" (как в конфиге)
                local section_name = io_name                
                -- Проверяем, что секция существует и включена
                local gpio_config = gpio.confgpio.gpio_config_cache[section_name]
                if gpio_config and gpio_config.status == "enable" then
                    local action_cmd = gpio_config.action_command
                    print("Action command for " .. io_name .. ": " .. (action_cmd or "not set"))                  
                    -- Если команда задана - выполняем
                    if action_cmd and action_cmd ~= "" then
                        print("Executing: " .. action_cmd)
                        os.execute(action_cmd)
                    end
                else
                    print("No config found for " .. section_name .. " or GPIO disabled")
                end
            end
        end
        gpio.notifier.gpio_change_detected = false
    end
end

local metatable = {
	__call = function(gpio, confgpio, state, notifier, timer)
		gpio.confgpio = confgpio
		gpio.state = state
		gpio.notifier = notifier
		gpio.timer = timer

		uloop.init()
		
		gpio:init()
		gpio.state:init(gpio, confgpio, notifier, timer)
		gpio.state:make_ubus()
		gpio.confgpio:init(gpio, state, notifier, timer)
		gpio.notifier:init(gpio, state, confgpio, timer)
		gpio.timer:init(gpio, state, confgpio, notifier)

		gpio.notifier:Run()

		uloop.run()

		return gpio
	end
}

setmetatable(gpio, metatable)

return gpio
