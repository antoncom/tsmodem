
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
		--input = "Правило журналирования статуса регистрации в сети",
		input = "Indication: update the UI when the celluar network state is changed.",
		output = "",
		subtotal = nil,
		modifier = {}
	},

	event_datetime = {
		source = {
			model = "tsmodem.driver",
			method = "reg",
			param = "time"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'return(os.date("%Y-%m-%d %H:%M:%S", tonumber("event_datetime")))'
		}
	},

	event_is_new = {
		source = {
			model = "tsmodem.driver",
			method = "reg",
			param = "unread"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {

		}
	},

	event_reg = {
		source = {
			model = "tsmodem.driver",	-- This is UBUS OBJECT name. Run in the shell "ubus list | grep tsmodem" to see all objects.
			method = "reg",				-- This is UBUS METHOD name. Run in the shell "ubus -v list tsmodem driver" to see all nethods.
			param = "value"				-- This is requested param name. Only "value", "time" and "command" are only possible here.
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
			["1_logicfunc"] = [[ if ("event_is_new" == "true") then return true else return false end ]],
			["2_formula"] = [[return({
					datetime = "event_datetime",
					name = "Network registration staus was changed",
					source = "Modem",
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
	self:load("event_is_new"):modify()
	self:load("event_reg"):modify()

	self:load("journal"):modify():clear() -- clear cache


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
