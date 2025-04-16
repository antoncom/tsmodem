local debug_mode = require "applogic.debug_mode"
local rule_init = require "applogic.util.rule_init"
local log = require "applogic.util.log"

local rule = {}
local rule_setting = {
	title = {
		input = "Правило GPIO линия 0. Конфиг:/etc/config/tsmgpio",
	},

	cfg_status = {
		note = "Конфигурация. Линия: задействована/незадействована",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "status"
            },
        },
        modifier = {
			["1_bash"] = [[ jsonfilter  -e $.value ]],
		}
	},

	set_line_to_hw_save_mod = {
		note = "Переводит линию в безопасный режим: вход",
		input = "",
		source = {
			type = "ubus",
            object = "tsmodem.gpio",
            method = "IO0",
            params = {
                value = "",
                direction = "in",
                trigger = "none"
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_status ~= "disable")]],
        }
	},

	cfg_value = {
		note = "Конфигурация. Запись состояния из конфига в линию",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "value"
            },
        },
        modifier = {
			["1_bash"] = [[ jsonfilter  -e $.value ]]
		}
	},

	cfg_trigger = {
		note = "Конфигурация. Активация захвата события по: фронту/спаду/любое",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "trigger"
            },
        },
        modifier = {
			["1_skip"] = [[ return ($cfg_status == "disable")]],
			["2_bash"] = [[ jsonfilter  -e $.value ]],		
		}
	},

	cfg_direction = {
		note = "Конфигурация. Направление: вход/выход",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "direction"
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_status == "disable") ]],
			["2_bash"] = [[ jsonfilter  -e $.value ]],
		}
	},				

	set_direction_in = {
		note = "Установка направления линии на вход.",
		input = "",
        source = {
			type = "ubus",
            object = "tsmodem.gpio",
            method = "IO0",
            params = {
                value = "",
                direction = "in",
                trigger = "$cfg_trigger"
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_direction ~= "in") ]],
        }
	},

	set_direction_out = {
		note = "Установка направления линии на выход.",
		input = "",
        source = {
			type = "ubus",
            object = "tsmodem.gpio",
            method = "IO0",
            params = {
                value = "$cfg_value",
                direction = "out",
                trigger = ""
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_direction ~= "out") ]],
        }
	},

	cfg_debounce_ms = {
		note = "Конфигурация. Фильтрация дребезга контактов в мсек.",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "debounce_ms"
            },
        },
        modifier = {
			["1_bash"] = [[ jsonfilter  -e $.value ]]
		}
	},

	value_status = {
		note = "Текущее состояние линии.",
		input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO0",
            params = {
                value = "",
                direction = "$cfg_direction",
                trigger = "$cfg_trigger"
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_status == "disable") ]],
			["2_bash"] = [[ jsonfilter -e '$.response.value' ]],
		}
	},

    value_status_sub = {
        note = "Подписка на tsmodem.gpio",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO5"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

	cfg_action_command = {
		note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "action_command"
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_status == "disable") or ($cfg_direction == "out") ]],
			["2_bash"] = [[ jsonfilter  -e $.value ]],
			["3_func"] = [[
				-- Проверка, сколько раз срабатывает блок:
				if ($last_value ~= $value_status) then
					-- Начальное значение N
					local N = 0
					local last_value = "some_value" -- Замените на ваше значение
					local value_status = "new_value" -- Замените на ваше значение
					-- Функция для создания файла
    				N = N + 1
    				local filename = string.format("/var/rules/19_rule_Action_%d.txt", N) -- Создаем имя файла
    				local file = io.open(filename, "w") -- Открываем файл для записи
					if file then
        				file:write("This is file number " .. N) -- Записываем в файл
        				file:close() -- Закрываем файл
					end
				end
			]]
		}
	},

	cfg_hw_info = {
		note = "Информация об аппапатной реализации GPIO.",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "hw_info"
            },
        },
        modifier = {
			["1_bash"] = [[ jsonfilter  -e $.value ]]
		}
	},	
}

function rule:make()
	debug_mode.level = "ERROR"
	rule.debug_mode = debug_mode
	local ONLY = rule.debug_mode.level

	-- These variables are included into debug overview (run "applogic debug" to get all rules overview)
	-- Green, Yellow and Red are measure of importance for Application logic
	-- Green is for timers and some passive variables,
	-- Yellow is for that vars which switches logic - affects to normal application behavior
	-- Red is for some extraordinal application ehavior, like watchdog, etc.
	local overview = {
		["do_switch"] = { ["yellow"] = [[ return ($do_switch == "true") ]] },
		["timeout"] = { ["yellow"] = [[ return (tonumber($timeout) and tonumber($timeout) < 600) ]] },
		["send_command"] = { ["yellow"] = [[ return ($send_command == "true") ]] },
		["a_balance_interval"] = { ["green"] = [[ return true ]] },
	}

	self:load("title"):modify():debug()
	--self:load("cfg_status"):modify():debug()
	--self:load("cfg_value"):modify():debug()
	--self:load("cfg_trigger"):modify():debug()
	--self:load("cfg_direction"):modify():debug()
    self:load("value_status_sub"):modify():debug()
	--self:load("set_line_to_hw_save_mod"):modify():debug()
	--self:load("set_direction_in"):modify():debug()
	--self:load("set_direction_out"):modify():debug()
	--self:load("value_status"):modify():debug()
	--self:load("last_value"):modify():debug()
	--self:load("cfg_debounce_ms"):modify():debug()
	--self:load("cfg_action_command"):modify():debug()
	self:load("cfg_hw_info"):modify():debug()

end

---[[ Initializing. Don't edit the code below ]]---
local metatable = {
	__call = function(table, parent)
		local t = rule_init(table, rule_setting, parent)
		if not t.is_busy then
			t.is_busy = true
			t:make()
			t.is_busy = false
		end
		return t
	end
}
setmetatable(rule, metatable)
return rule