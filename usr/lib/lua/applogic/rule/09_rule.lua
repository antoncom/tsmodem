local debug_mode = require "applogic.debug_mode"
local rule_init = require "applogic.util.rule_init"
local log = require "applogic.util.log"

local rule = {}
local rule_setting = {
	title = {
		input = "Правило для GPIO: IO0..IO7. Конфиг:/etc/config/tsmgpio",
	},

    cfg_status = {
        note = "Конфигурация. Линии: задействованы/незадействованы",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "general",
                option = "isActive"
            },
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },    			
----------------------------IO0--------------------------------------
    io0_current_state = {
        note = "Текущее состояние IO0.",
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

    io0_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO0",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io0_event_counter = {
        note = "Счетчик активации триггера IO0",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO0"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO0.value ]],
        }
    },

    io0_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 0 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io0_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io0_cfg_action_command)
            ]],
        }
    },
----------------------------IO1--------------------------------------
    io1_current_state = {
        note = "Текущее состояние IO1.",
        input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO1",
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

    io1_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO1",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io1_event_counter = {
        note = "Счетчик активации триггера IO1",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO1"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO1.value ]],
        }
    },

    io1_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 1 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io1_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io1_cfg_action_command)
            ]],
        }
    },  
----------------------------IO2--------------------------------------
    io2_current_state = {
        note = "Текущее состояние IO2.",
        input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO2",
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

    io2_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO2",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io2_event_counter = {
        note = "Счетчик активации триггера IO2",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO2"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO2.value ]],
        }
    },

    io2_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 2 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io2_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io2_cfg_action_command)
            ]],
        }
    },
----------------------------IO3--------------------------------------
    io3_current_state = {
        note = "Текущее состояние IO3.",
        input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO3",
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

    io3_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO3",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io3_event_counter = {
        note = "Счетчик активации триггера IO3",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO3"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO3.value ]],
        }
    },

    io3_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 3 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io3_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io3_cfg_action_command)
            ]],
        }
    },
----------------------------IO4--------------------------------------
    io4_current_state = {
        note = "Текущее состояние IO4.",
        input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO4",
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

    io4_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO4",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io4_event_counter = {
        note = "Счетчик активации триггера IO4",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO4"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO4.value ]],
        }
    },

    io4_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 4 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io4_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io4_cfg_action_command)
            ]],
        }
    },
----------------------------IO5--------------------------------------
	io5_current_state = {
		note = "Текущее состояние IO5.",
		input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO5",
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

    io5_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO5",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io5_event_counter = {
        note = "Счетчик активации триггера IO5",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO5"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO5.value ]],
        }
    },

    io5_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 5 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io5_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io5_cfg_action_command)
            ]],
        }
    },
----------------------------IO6--------------------------------------
    io6_current_state = {
        note = "Текущее состояние IO6.",
        input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO6",
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

    io6_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO6",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io6_event_counter = {
        note = "Счетчик активации триггера IO6",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO6"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO6.value ]],
        }
    },

    io6_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 6 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io6_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io6_cfg_action_command)
            ]],
        }
    },
----------------------------IO7--------------------------------------
    io7_current_state = {
        note = "Текущее состояние IO7.",
        input = "",
        source = {
            type = "ubus",
            object = "tsmodem.gpio",
            method = "IO7",
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

    io7_cfg_action_command = {
        note = "Конфигурация. Реакция на событие: Запуск Bash-команды.",
        input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO7",
                option = "action_command"
            },
        },
        modifier = {
            ["1_skip"] = [[ return ($cfg_status == "disable") ]],
            ["2_bash"] = [[ jsonfilter  -e $.value ]],
        }
    },

    io7_event_counter = {
        note = "Счетчик активации триггера IO7",
        input = "",
        source = {
            type = "subscribe",
            ubus = "tsmodem.gpio",
            evname = "tsmodem.gpio_update",
            match = {gpio_port="IO7"}
        },
        modifier = {
            ["1_bash"] = [[ jsonfilter  -e $.IO7.value ]],
        }
    },

    io7_action_command_run = {
        note = [[ Запуск скрипта, привязанного к 7 линии ]],
        input = 0,
        modifier = {
            ["1_skip"] = [[ return ($io7_event_counter == "") ]],
            ["2_func"] = [[
                os.execute($io7_cfg_action_command)
            ]],
        }
    },  
---------------------------------------------------------------------
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
	self:load("cfg_status"):modify():debug()
----------------------------IO0--------------------------------------              
    self:load("io0_current_state"):modify():debug()
    self:load("io0_cfg_action_command"):modify():debug()
	self:load("io0_event_counter"):modify():debug()
    self:load("io0_action_command_run"):modify():debug()
----------------------------IO1--------------------------------------              
    self:load("io1_current_state"):modify():debug()
    self:load("io1_cfg_action_command"):modify():debug()
    self:load("io1_event_counter"):modify():debug()
    self:load("io1_action_command_run"):modify():debug()
----------------------------IO2--------------------------------------              
    self:load("io2_current_state"):modify():debug()
    self:load("io2_cfg_action_command"):modify():debug()
    self:load("io2_event_counter"):modify():debug()
    self:load("io2_action_command_run"):modify():debug()
----------------------------IO3--------------------------------------              
    self:load("io3_current_state"):modify():debug()
    self:load("io3_cfg_action_command"):modify():debug()
    self:load("io3_event_counter"):modify():debug()
    self:load("io3_action_command_run"):modify():debug()
----------------------------IO4--------------------------------------              
    self:load("io4_current_state"):modify():debug()
    self:load("io4_cfg_action_command"):modify():debug()
    self:load("io4_event_counter"):modify():debug()
    self:load("io4_action_command_run"):modify():debug()
----------------------------IO5--------------------------------------              
    self:load("io5_current_state"):modify():debug()
    self:load("io5_cfg_action_command"):modify():debug()
    self:load("io5_event_counter"):modify():debug()
    self:load("io5_action_command_run"):modify():debug()
----------------------------IO6--------------------------------------              
    self:load("io6_current_state"):modify():debug()
    self:load("io6_cfg_action_command"):modify():debug()
    self:load("io6_event_counter"):modify():debug()
    self:load("io6_action_command_run"):modify():debug()
----------------------------IO7--------------------------------------              
    self:load("io7_current_state"):modify():debug()
    self:load("io7_cfg_action_command"):modify():debug()
    self:load("io7_event_counter"):modify():debug()
    self:load("io7_action_command_run"):modify():debug()
--------------------------------------------------------------------           
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