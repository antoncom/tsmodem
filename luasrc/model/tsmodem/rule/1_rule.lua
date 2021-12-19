
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

local rule_setting = {
	title = {
		input = "Правило переключения Сим-карты, если не в сети",
		output = "",
		subtotal = nil,
		modifier = {}
	},

	sim_id = {
		source = {
			model = "tsmodem.driver",
			method = "sim",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {}
	},

	uci_section = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ("sim_id" == "0" or "sim_id" == "1") then return ("sim_" .. "sim_id") else return "sim_0" end ]]
		}
	},

	uci_timeout_reg = {
		source = {
			model = "uci",
			config = "tsmodem",
			section = "uci_section",
			option = "timeout_reg"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ( "uci_timeout_reg" == "" or tonumber("uci_timeout_reg") == nil ) then return "99" else return "uci_timeout_reg" end ]]
		}
	},

	network_registration = {
		source = {
			model = "tsmodem.driver",
			method = "reg",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_ui-update"] = {
				param_list = { "network_registration", "sim_id" }
			}
		}
	},

	changed_reg_time = {
		source = {
			model = "tsmodem.driver",
			method = "reg",
			param = "time"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'if("changed_reg_time" == "" or tonumber("changed_reg_time") == nil) then return "0" else return "changed_reg_time" end'
		}
	},

	lastreg_timer = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'if ("network_registration" ~= "1" and "network_registration" ~= "7") then return( tostring(os.time() - tonumber("changed_reg_time")) ) else return("0") end ',
			["2_ui-update"] = {
				param_list = { "lastreg_timer", "sim_id" }
			}
		}
	},

	--[[ Before switching SIM it sends "begin" to web interface in order to show overlay and block any user activities ]]
	event_switch_state = {
		input = "",
		output = "",
		subtotal = "",
		modifier = {
			["1_formula"] = [[ if (
					( "do_switch_result" ~= "not-ready-to-switch" )
				and	( "do_switch_result" ~= "disconnected" )
				and	( "network_registration" ~= "1" )
				and ( tonumber("lastreg_timer") > tonumber("uci_timeout_reg") )
			) then return "begin" else return "" end ]],
			["2_ui-update"] = {
				param_list = { "event_switch_state", "sim_id" }
			}
		}
	},

	do_switch_result = {
		source = {
			model = "tsmodem.driver",
			method = "do_switch",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_logicfunc"] = [[ if (
					( "do_switch_result" ~= "not-ready-to-switch" )
				and	( "do_switch_result" ~= "disconnected" )
				and	( "network_registration" ~= "1" )
				and ( tonumber("lastreg_timer") > tonumber("uci_timeout_reg") )
			) then return true else return false end ]],
		},
		["2_formula"] = [[return({
				datetime = "event_datetime",
				name = "No network registration: switched to another SIM",
				source = "Microcontroller",
				command = "do_switch_result",
				response = "OK"
			})]],
		["3_ui-update"] = {
			param_list = { "do_switch_result" }
		}
	},
}

function rule:logicfunc(varname)
	return logicfunc:logicfunc(varname, self.setting)
end

function rule:modify(varname)
	return modifier:modify(varname, self.setting)
end

function rule:load(varname, ...)
	return loadvar(rule, varname, ...)
end


function rule:make()

	self:load("title"):modify()
	self:load("sim_id"):modify()
	self:load("uci_section"):modify()
	self:load("uci_timeout_reg"):modify()
	self:load("network_registration"):modify()
	self:load("changed_reg_time"):modify()
	self:load("lastreg_timer"):modify()
	self:load("event_switch_state"):modify()

	self:load("do_switch_result"):modify():clear()


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
