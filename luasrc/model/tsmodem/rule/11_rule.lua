
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"
local I18N = require "luci.i18n"

local loadvar = require "luci.model.tsmodem.loadvar"
local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local rule = {}
rule.ubus = {}
rule.is_busy = false
rule.events_queue = {}


local rule_setting = {
	title = {
		--input = "Правило журналирования событий Микроконтроллера",
		input = "Indication: add to the system log all events of STM32 microcontroller.",
		output = "",
		subtotal = nil,
		modifier = {}
	},

	event_datetime = {
		source = {
			model = "tsmodem.driver",
			method = "stm",
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
			method = "stm",
			param = "unread"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {

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

	--[[ After switching SIM was completed it sends "end" to web interface in order to hide overlay and allow any user activities ]]
	event_switch_state = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ if ( (string.sub("event_stm_command",1,12) == "~0:SIM.RST=1") and ("event_is_new" == "true") ) then return "end" else return "" end ]],
			["2_ui-update"] = {
				param_list = { "event_switch_state" }
			}
		}
	},


	journal = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_logicfunc"] = [[ if ("event_is_new" == "true") then return true else return false end ]],
			["2_formula"] = [[return({
					datetime = "event_datetime",
					name = "]] .. I18N.translate("Executing the command") .. [[",
					source = "]] .. I18N.translate("Microcontroller") .. [[",
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
	self:load("event_is_new"):modify()
	self:load("event_stm_command"):modify()
	self:load("event_stm_value"):modify()
	self:load("event_switch_state"):modify()

	self:load("journal"):modify():clear()

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
