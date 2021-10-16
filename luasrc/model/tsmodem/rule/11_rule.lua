
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"

local loadvar = require "luci.model.tsmodem.loadvar"
local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local rule = {}
rule.ubus = {}
rule.is_busy = false
rule.events_queue = {}


local rule_setting = {
	title = {
		input = "Правило журналирования событий Микроконтроллера",
		output = "",
		subtotal = nil,
		modifier = {}
	},

	event_datetime = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'return(os.date("%Y-%m-%d %H:%M:%S"))'
		}
	},

	event_stm_command_old = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ return("event_stm_command")]]
		}
	},

	event_stm_command = {
		source = {
			model = "tsmodem.driver",
			method = "stm",
			param = "command"
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {}
	},

	event_stm_value_old = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ return("event_stm_value")]]
		}
	},

	event_stm_value = {
		source = {
			model = "tsmodem.driver",
			method = "stm",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {}
	},
	event_stm_changed = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ if( "event_stm_command" ~= "event_stm_command_old" or  "event_stm_command" ~= "event_stm_command_old") then return "true" else return "false" end ]]
		}
	},
	event_stm_command = {
		source = {
			model = "tsmodem.driver",
			method = "stm",
			param = "command"
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {}
	},


	journal = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_logicfunc"] = [[ if ("event_stm_changed" == "true") then return true else return false end ]],
			["2_formula"] = [[return({
					datetime = "event_datetime",
					name = "Выполнение команды",
					source = "Микроконтроллер",
					command = "event_stm_command",
					response = "event_stm_value"
				})]],
			["3_ui-update"] = {
				param_list = { "journal" }
			}
		}
	},

}

function rule:logicfunc(varname)
	return logicfunc:logicfunc(varname, self.setting)
end

function rule:modify(varname)
	--log("SELFSET", self.setting)
	return modifier:modify(varname, self.setting)
end


function rule:load(varname, ...)
	return loadvar(rule, varname, ...)
end


function rule:make()

	self:load("title"):modify()
	self:load("event_datetime"):modify()
	self:load("event_stm_command_old"):modify()
	self:load("event_stm_command"):modify()

	self:load("event_stm_value_old"):modify()
	self:load("event_stm_value"):modify()

	self:load("event_stm_changed"):modify()

	self:load("journal"):modify()

end



local metatable = {
	__call = function(table, parent)
		table.setting = rule_setting

		table.ubus = parent.ubus_object
		table.conn = parent.conn

		if not table.is_busy then
			table.is_busy = true
			table:make()
			table.is_busy = false
		end

		return table
	end
}
setmetatable(rule, metatable)

return rule
