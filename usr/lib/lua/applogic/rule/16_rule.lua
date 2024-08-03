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

	allowed_commands = {
		note = [[ Разрешеный список команд оболочки ]],
		source = {
			type = "ubus",
			object = "uci",
			method = "get",
			params = {
				config = "tsmodem",
				section = "remote_control",
				option = "allowed_bash_commands",
			}
		},
        modifier = {
            ["1_bash"] = [[ jsonfilter -e $.value ]],
            ["2_func"] = [[
				local bash_commands = {}
				-- Разделение строки по символу "пробел"
				for bufer in string.gmatch($allowed_commands, "[^ ]+") do
  					table.insert(bash_commands, bufer)
				end
				return bash_commands
			]], 
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
			["2_func"] = [[
				local command_true = false
				local command_buf
				-- Проверка наличия команды в списке
				for _, command_buf in ipairs($allowed_commands) do
  					if command_buf == $sms_command_recive then
    					command_true = true
    					break
  					end
				end
				if ($sms_phone_number_recive == $trusted_phone_numbers) and ($sms_is_read == "true") and command_true then
					local response = io.popen($allowed_commands):read("*a")
					if #response < 160 then
						local command = string.format("ubus call tsmodem.driver send_sms '{\"command\":\"%s\", \"value\":\"%s\"}'", response, $sms_phone_number_recive)
						os.execute(command)
					else
						command = string.format("echo '%s' | ssmtp -vvv anti1800@mail.com", response)
						os.execute(command)
					end
				end
				if not command_true then
					-- отправить смс извещение о недопустимости команды
				end
				return "testing txt"
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
	self:load("allowed_commands"):modify():debug()
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
