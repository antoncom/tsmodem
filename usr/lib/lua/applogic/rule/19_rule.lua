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
			["1_bash"] = [[ jsonfilter  -e $.value ]]
		}
	},

	cfg_default_value_out = {
		note = "Конфигурация. Линия в начальном состоянии в режиме выход",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                option = "default_value_out"
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
			["3_func"] = [[
				local JUST_STARTED = true
				local def_value = $cfg_value
				local def_direction = $cfg_direction
				local def_trigger = $cfg_trigger
				-- Инициализация направления из конфига при первом запуске
				if (JUST_STARTED) then
					-- В режиме вход требуется только такое сочетание параметров
					if (def_direction == 'in') then
						def_value = ''
					end
					-- В режиме выход устанавливается безопасное состояние линии
					if (def_direction == 'out') then
						def_value = $cfg_default_value_out
						def_trigger = ''
					end					
					local command = "ubus call tsmodem.gpio IO0 '{\"value\":\"" .. def_value .. 
											"\",\"direction\":\"" .. def_direction .. 
											"\",\"trigger\":\"" .. def_trigger .. "\"}'"
					local handle = io.popen(command)
					local result = handle:read("*a")  -- перенаправление ответа
					handle:close()
					JUST_STARTED = false
				end
				return def_direction
			]]
		}
	},	

	cfg_value_out = {
		note = "Конфигурация. Для режима выход. Запись данных в линию.",
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
        	["1_skip"] = [[ return ($cfg_status == "disable") or ($cfg_direction == "in")]],
			["2_bash"] = [[ jsonfilter  -e $.value ]],
			["3_func"] = [[
				local def_value = $cfg_value_out
				local def_direction = "out"
				local def_trigger = ""
				local command = "ubus call tsmodem.gpio IO0 '{\"value\":\"" .. def_value .. 
											"\",\"direction\":\"" .. def_direction .. 
											"\",\"trigger\":\"" .. def_trigger .. "\"}'"
				local handle = io.popen(command)
				local result = handle:read("*a")  -- перенаправление ответа
				handle:close()
			]]
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

	value_in = {
		note = "Чтение состояния линии",
		input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO0",
            params = {
            	-- TODO: подправить драйвер UBUS для работы с таким сочетанием
            	-- параметров. Протестировать на железе!
                value = "",
                direction = "",
                trigger = ""
            },
        },
        modifier = {
        	["1_skip"] = [[ return ($cfg_status == "disable") ]],
			["2_bash"] = [[ jsonfilter -e '$.response.value' ]],
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
			["1_bash"] = [[ jsonfilter  -e $.value ]]
		}
	},

	cfg_hw_info = {
		note = "Конфигурация. Информация об аппапатной реализации GPIO.",
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

	direction = {
		note = [[ Направление: вход/выход ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
            params = {
                value = "0",
                direction = "",
                trigger = ""
            },
		},
		modifier = {
			["1_skip"] = [[ return ($cfg_status == "disable") ]],
			["2_bash"] = [[ jsonfilter -e '$.response.direction' ]]
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
	self:load("cfg_status"):modify():debug()
	self:load("cfg_default_value_out"):modify():debug()
	self:load("cfg_direction"):modify():debug()
	self:load("cfg_trigger"):modify():debug()
	self:load("cfg_value"):modify():debug()
	--self:load("cfg_debounce_ms"):modify():debug()
	self:load("cfg_action_command"):modify():debug()
	self:load("cfg_hw_info"):modify():debug()
	--self:load("direction"):modify():debug()

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