
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
		input = "Правило переключения Сим-карты, если уровень сигнала ниже нормы.",
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
			["1_formula"] = [[ if ("sim_id" == "0" or "sim_id" == "1") then return "sim_" .. "sim_id" else return "sim_0" end ]]
		}
	},

	uci_signal_min = {
		source = {
			model = "uci",
			config = "tsmodem",
			section = "uci_section",
			option = "signal_min"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ( "uci_signal_min" == "" or tonumber("uci_signal_min") == nil ) then return "5" else return "uci_signal_min" end ]]
		}
	},

	uci_timeout_signal = {
		source = {
			model = "uci",
			config = "tsmodem",
			section = "uci_section",
			option = "timeout_signal"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ( "uci_timeout_signal" == "" or tonumber("uci_timeout_signal") == nil ) then return "99" else return "uci_timeout_signal" end ]]
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
		}
	},

	signal = {
		source = {
			model = "tsmodem.driver",
			method = "signal",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'if (tonumber("signal") == nil or "signal" == "99" or "signal" == "31" or "signal" == "" or "signal" == "0") then return("101") else return("signal") end',
			["2_formula"] = 'if ("network_registration" == "7" or "network_registration" == "6" or "network_registration" == "0") then return("101") else return("signal") end',
			["3_formula"] = 'if ("signal" ~= "101") then return(tostring(math.ceil(tonumber("signal") * 100 / 31))) else return("signal") end',
            ["4_ui-update"] = {
                param_list = { "signal", "sim_id" }
            }
		},
	},

	signal_time = {
		source = {
			model = "tsmodem.driver",
			method = "signal",
			param = "time"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
		}
	},


	signal_normal_last_time = {
		input = tostring(os.time()),
		output = "",
		subtotal = nil,
		modifier = {
			["1-logicfunc"] = [[ if (tonumber("signal") > tonumber("uci_signal_min")) then return true else return false end ]],
			["2_formula"] = [[ return tostring(os.time()) ]],
			["3_ui-update"] = {
				param_list = { "signal_normal_last_time", "signal", "uci_signal_min" }
			}
		}
	},

	low_signal_timer = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ( tonumber("signal") < tonumber("uci_signal_min") )
				then return( tostring(os.time() - tonumber("signal_normal_last_time")) ) else return("0") end ]],
			["2_ui-update"] = {
				param_list = { "low_signal_timer", "sim_id" }
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
					( "do_switch_low_signal" ~= "not-ready-to-switch" )
				and	( "do_switch_low_signal" ~= "disconnected" )
				and	( tonumber("signal") < tonumber("uci_signal_min") )
				and ( tonumber("low_signal_timer") > tonumber("uci_timeout_signal") )
			) then return "begin" else return "" end ]],
			["2_ui-update"] = {
				param_list = { "event_switch_state", "sim_id" }
			}
		}
	},

	do_switch_low_signal = {
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
					( "do_switch_low_signal" ~= "not-ready-to-switch" )
				and	( "do_switch_low_signal" ~= "disconnected" )
				and	( tonumber("signal") < tonumber("uci_signal_min") )
				and ( tonumber("low_signal_timer") > tonumber("uci_timeout_signal") )
			) then return true else return false end ]],
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
	self:load("uci_signal_min"):modify()
	self:load("uci_timeout_signal"):modify()
	self:load("network_registration"):modify()
	self:load("signal"):modify()
	self:load("signal_time"):modify()
	self:load("signal_normal_last_time"):modify()
	self:load("low_signal_timer"):modify()
	self:load("event_switch_state"):modify()

	self:load("do_switch_low_signal"):modify():clear()


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
