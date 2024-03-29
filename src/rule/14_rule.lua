
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local ubus = require "ubus"
local I18N = require "luci.i18n"

local loadvar = require "tsmodem.loadvar"
local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local rule = {}
rule.ubus = {}
rule.is_busy = false
rule.events_queue = {}


local rule_setting = {
	title = {
		input = I18N.translate("Indication: update GSM provider name"),
		output = "",
		subtotal = nil,
		modifier = {}
	},

	event_datetime = {
		source = {
			model = "tsmodem.driver",
			method = "provider_name",
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
			method = "provider_name",
			param = "unread"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {

		}
	},

	sim_id = {
		source = {
			model = "tsmodem.driver",
			method = "sim",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {

		}
	},

	provider_name = {
		source = {
			model = "tsmodem.driver",	-- This is UBUS OBJECT name. Run in the shell "ubus list | grep tsmodem" to see all objects.
			method = "provider_name",				-- This is UBUS METHOD name. Run in the shell "ubus -v list tsmodem driver" to see all nethods.
			param = "value"				-- This is requested param name. Only "value", "time" and "command" are only possible here.
		},
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_ui-update"] = {
				param_list = { "provider_name", "sim_id" }
			}
		}
	},

	journal = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_logicfunc"] = [[ if ( ("event_is_new" == "true") and "provider_name" ~= nil and "provider_name" ~= "" ) then return true else return false end ]],
			["2_formula"] = [[return({
					datetime = "event_datetime",
					name = "]] .. I18N.translate("GSM provider was identified") .. [[",
					source = "]] .. I18N.translate("Modem") .. [[",
					command = "+NITZ",
					response = "provider_name"
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
	self:load("sim_id"):modify()
	self:load("provider_name"):modify()

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
