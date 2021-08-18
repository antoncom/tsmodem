
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
		input = "Правило журналирования статуса регистрации в сети",
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

	event_reg_old = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ return("event_reg")]]
		}
	},
	event_reg = {
		source = {
			model = "tsmodem.driver",
			method = "reg",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {}
	},
	event_reg_changed = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ if "event_reg" ~= "event_reg_old" then return "true" else return "false" end	]]
		}
	},


	journal = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_logicfunc"] = [[ if ("event_reg_changed" == "true") then return true else return false end ]],
			["2_formula"] = [[return({
					datetime = "event_datetime",
					name = "Изменился статус регистрации в сети",
					source = "Модем",
					command = "AT+CREG?",
					response = "event_reg"
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
	self:load("event_reg_old"):modify()
	self:load("event_reg"):modify()
	self:load("event_reg_changed"):modify()

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
