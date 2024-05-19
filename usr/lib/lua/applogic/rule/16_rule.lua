local debug_mode = require "applogic.debug_mode"
local rule_init = require "applogic.util.rule_init"
local log = require "applogic.util.log"
local I18N = require "luci.i18n"

local rule = {}
local rule_setting = {
	title = {
		input = "Правило для дистанционного управления по СМС.",
	},
	
	trusted_phone_numbers = {
		note = [[ Доверенные номера телефонов ]],
		source = {
			type = "ubus",
			object = "uci",
			method = "get",
			params = {
				config = "tsmodem",
				section = "remote_control",
				option = "trusted_phone_numbers",
			}
		},
        modifier = {
            ["1_bash"] = [[ jsonfilter -e $.value ]],
        }
	},
	
	sms_phone_number_recive = {
		note = [[ Номер телефона, отправившего смс ]],
		source = {
			type = "ubus",
			object = "tsmodem.driver",
			method = "remote_control",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},
	
	sms_is_read = {
		note = [[ Новое смс ]],
		source = {
			type = "ubus",
			object = "tsmodem.driver",
			method = "remote_control",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.unread ]]
		}	
	},

	sms_command_recive = {
		note = [[ Команда, принятая по смс ]],
		source = {
			type = "ubus",
			object = "tsmodem.driver",
			method = "remote_control",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.command ]],
			--["2_save"] = [[ return $sms_command_recive ]],
			["3_func"] = [[ 
				if ($sms_phone_number_recive == $trusted_phone_numbers) and 
					($sms_is_read == "true") then
					os.execute($sms_command_recive)
				end 
				return $sms_command_recive
			]],
		}
	},
}

-- Use "ERROR", "INFO" to override the debug level
-- Use /etc/config/applogic to change the debug level
-- Use :debug(ONLY) - to debug single variable in the rule
function rule:make()
	debug_mode.level = "ERROR"
	rule.debug_mode = debug_mode
	local ONLY = rule.debug_mode.level
	
	local overview = {
	}
	
	self:load("title"):modify():debug()
	self:load("sms_phone_number_recive"):modify():debug()
	self:load("sms_is_read"):modify():debug()
	self:load("trusted_phone_numbers"):modify():debug()
	self:load("sms_command_recive"):modify():debug()
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
