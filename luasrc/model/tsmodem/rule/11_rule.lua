
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"

local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"

local PROTO = "STM32"
local EVENT_SOURCE_NAME = "Микроконтроллер"
local EVENT_TITLES = {
	["~0:SIM.SEL=0"] = "Переключение СИМ-карты",
	["~0:SIM.SEL=?"] = "Определение активной СИМ-карты",
	["~0:SIM.SEL=1"] = "Переключение СИМ-карты",
	["~0:SIM.RST=0"] = "Подан сигнал сброса на модем",
	["~0:SIM.RST=1"] = "Снят сигнал сброса с модема"
}


local rule = {} 
rule.ubus = {}
rule.subscribed = false


local rule_setting = {
	title = {
		source_value = "Правило журналирования событий Микроконтроллера",
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

	event_command = {
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

	event_response = {
		source_value = "",
		target_value = "",
		target_modifier = {
			--["1_parser"] = "tsmodem.parser.stm"
			["1_formula"] = 'if("event_response" == "OK") then return "1" end'
		}
	},

	event_response_old = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_formula"] = 'if("event_response" ~= "") then return "event_response" else return "event_response_old" end'
		}	-- Does not update "event_response_old" if "event_response" is blank. Think that it was parsing mistake.

	},


	journal = {
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_logicfunc"] = [[
				if not (("event_command" == "event_command_old" and "event_response" == "event_response_old")
				) then return true else return false end
			]],
			["2_formula"] = [[return({ 
					datetime = "event_datetime", 
					name = "event_name", 
					source = "Микроконтроллер", 
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

						log("--- " .. PROTO .. " ----", data)

						-- Populate self-generated and constants

						for _, name in ipairs({"event_command_old", "event_response_old", "event_datetime", "title", "id"}) do
							self:modify(name)
						end

						-- Populate data on subscribtion

						self.setting.event_name.source_value = EVENT_TITLES[command] or ""
						self:modify("event_name")
	

						self.setting.event_command.source_value = command or ""
						self:modify("event_command")


						self.setting.event_response.source_value = response or ""
						self:modify("event_response")

						-- Publish journal only if Logicfunc modifier returns True
						
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