local debug_mode = require "applogic.debug_mode"
local rule_init = require "applogic.util.rule_init"
local log = require "applogic.util.log"

local rule = {}
local rule_setting = {
	title = {
		input = "Правило периодического опроса GPIO",
	},

	IO0_config = {
		note = "Конфигурация GPIO из /etc/config/tsmgpio",
		input = "",
        source = {
            type = "ubus",
            object = "uci",
            method = "get",
            params = {
                config = "tsmgpio",
                section = "IO_0",
                --option = "direction"
            },
        },
	},

	IO0 = {
		note = [[ Идентификатор GPIO линия 0 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
            params = {
                value = "0",
                direction = "in",
                trigger = "none"
            },
		},
		modifier = {
			--["1_bash"] = [[ jsonfilter -e '$.response.value' ]]
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
	self:load("IO0_config"):modify():debug()
	self:load("IO0"):modify():debug()

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