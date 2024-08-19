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

	router_email = {
		note = [[ Доверенные номера телефонов ]],
		source = {
			type = "ubus",
			object = "uci",
			method = "get",
			params = {
				config = "tsmodem",
				section = "remote_control",
				option = "router_email",
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
				-- Трансформация строки из разрешенных команд в таблицу
				local allowed_commands_list = {}
				for word in string.gmatch($allowed_commands, "%S+") do
  					table.insert(allowed_commands_list, word)
				end
				-- Трансформация строки принятой команды в таблицу
				local sms_command_recive_list = {}
				for word in string.gmatch($sms_command_recive, "%S+") do
  					table.insert(sms_command_recive_list, word)
				end
				-- Проверка допустимости команды
				local command_true = false
				for _, command_buf in ipairs(allowed_commands_list) do
					if command_buf == sms_command_recive_list[1] then
						command_true = true
						break
					end
				end
				-- Выполнение команды по смс
				if $sms_phone_number_recive == $trusted_phone_numbers and $sms_is_read == "true" and command_true then
					local command
					local response
					response = io.popen($sms_command_recive):read("*a")
					if #response < 160 and #response > 1 then
						command = string.format("ubus call tsmodem.driver send_sms '{\"command\":\"%s\", \"value\":\"%s\"}'", response, $sms_phone_number_recive)
						os.execute(command)
					elseif #response >= 160 then
						-- Дублирование принятой команды в ответном сообщении
						response = "Command: " .. $sms_command_recive .."\n" .. response
						command = string.format("echo -e 'Subject: RTR-3\n\n%s' | ssmtp -vvv %s", response, $router_email)
						os.execute(command)
					else 
						response = "OK"
						command = string.format("ubus call tsmodem.driver send_sms '{\"command\":\"%s\", \"value\":\"%s\"}'", response, $sms_phone_number_recive)
						os.execute(command)
					end
				end 	
				return "TESTED"
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
	self:load("router_email"):modify():debug()
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
