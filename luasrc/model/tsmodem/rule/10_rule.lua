
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
		input = "Правило журналирования статуса подключения порта /dev/ttyUSB2",
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

	event_usb_old = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ return("event_usb")]]
		}
	},
	event_usb = {
		source = {
			model = "tsmodem.driver",
			method = "usb",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {}
	},
	event_usb_changed = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ if "event_usb" ~= "event_usb_old" then return "true" else return "false" end	]]
		}
	},
	event_usb_command = {
		source = {
			model = "tsmodem.driver",
			method = "usb",
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
			["1_logicfunc"] = [[ if ("event_usb_changed" == "true") then return true else return false end ]],
			["2_formula"] = [[return({
					datetime = "event_datetime",
					name = "Изменилось состояние порта /dev/ttyUSB2",
					source = "Устройство",
					command = "event_usb_command",
					response = "event_usb"
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
	self:load("event_usb_old"):modify()
	self:load("event_usb"):modify()
	self:load("event_usb_changed"):modify()
	self:load("event_usb_command"):modify()

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
