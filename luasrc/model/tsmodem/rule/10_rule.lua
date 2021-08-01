
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"

local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local PROTO = "AT"
local EVENT_SOURCE_NAME = "Модем"
local EVENT_TITLES = {
	["AT+CREG?"] 		= "Изменился статус регистрации в сети",
	["AT+CSQ"] 			= "Изменился уровень сигнала БС",
	["___todo___"] 		= "Остаток средств ниже нормы",
}



local rule = {} 
rule.ubus = {}
rule.subscribed = false


local rule_setting = {
	title = {
		source_value = "Правило журналирования событий Модема",
		target_value = "",
	},

	id = {
		source_value = "10_rule",
		target_value = "",
	},

	event_datetime = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_formula"] = 'return(os.date("%Y-%m-%d %H:%M:%S"))'
		}
	},

	event_name = {
		source_value = "",
		target_value = "",
	},

	event_command_old = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_formula"] = 'if("event_command" ~= "") then return "event_command" else return "event_command_old" end'
		}	-- Does not update "event_response_old" if "event_response" is blank. Think that it was parsing mistake.
	},

	event_command = {
		source_value = "",
		target_value = "",
	},

	event_response_old = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_formula"] = 'if("event_response" ~= "") then return "event_response" else return "event_response_old" end'
		}	-- Does not update "event_response_old" if "event_response" is blank. Think that it was parsing mistake.

	},

	event_response = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_parser"] = "tsmodem.parser.creg"
		}
	},

	journal = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_logicfunc"] = [[
				if not (("event_command" == "event_command_old" and "event_response" == "event_response_old")
					or	"event_response" == ""
				) then return true else return false end
			]],

			["2_formula"] = [[return({ 
					datetime = "event_datetime", 
					name = "event_name", 
					source = "Модем", 
					command = "event_command", 
					response = "event_response" 
				})]],
			["3_ui-update"] = {
				param_list = { "journal" }
			}
		}
	}
	
}

function rule:logicfunc(varname)
	return logicfunc:logicfunc(varname, self.setting)
end

function rule:modify(varname)
	return modifier:modify(varname, self.setting)
end

function rule:subscribe_once()
	if not self.subscribed then
		local possible_commands = util.keys(EVENT_TITLES)

		self.conn:subscribe("tsmodem.driver", {
			notify = function(data, proto)
				if(proto == PROTO) then

					local command = data["command"] or ""
					local response = data["response"] or ""

					if(util.contains(possible_commands, command)) then

						-- Populate self-generated and constants

						for _, name in ipairs({"event_datetime", "title", "id"}) do
							self:modify(name)
						end

						--log("::::: RULE 11 ::::: ", self.setting)

						-- Populate data on subscribtion

						self.setting.event_name.source_value = EVENT_TITLES[command] or ""
						self:modify("event_name")

						self.setting.event_command_old.source_value = self.setting.event_command_old.target_value or ""
						self:modify("event_command_old")

						self.setting.event_command.source_value = command or ""
						self:modify("event_command")

						self.setting.event_response_old.source_value = self.setting.event_response_old.target_value or ""
						self:modify("event_response_old")

						self.setting.event_response.source_value = response or ""
						self:modify("event_response")

						-- Publish journal only if Logicfunc target_modifier returns True
						
						if(self:logicfunc("journal") == true) then
							self:modify("journal")
						end

					end
				end
			end
		})
		self.subscribed = true
	end
end


local metatable = { 
	__call = function(table, parent)
		table.setting = rule_setting

		table.ubus = parent.ubus_object
		table.conn = parent.conn
		table:subscribe_once()	
		

		return table
	end
}
setmetatable(rule, metatable)

return rule