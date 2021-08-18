
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"

local loadvar = require "luci.model.tsmodem.loadvar"
local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local reg_timeout = 90

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
			["1_formula"] = 'if ("signal" == "99" or "signal" == "31" or "signal" == "" or "signal" == "0") then return("-") else return("signal") end',
			["2_formula"] = 'if ("network_registration" == "7" or "network_registration" == "6" or "network_registration" == "0") then return("-") else return("signal") end',
			["3_formula"] = 'if ("signal" ~= "-") then return(tostring(math.ceil(tonumber("signal") * 100 / 31))) else return("signal") end',
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
				param_list = { "network_registration", "sim_id", "signal" }
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
		modifier = {}
	},

	lastreg_timer = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'if ("network_registration" ~= "1" and "network_registration" ~= "7") then return( tostring(os.time() - tonumber("changed_reg_time")) ) else return("0") end ',
			["2_ui-update"] = {
				param_list = { "lastreg_timer" }
			}
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
		subtotal = nil,
		modifier = {}
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
				and ( tonumber("lastreg_timer") > ]] .. tostring(reg_timeout) .. [[ )
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
	self:load("signal"):modify()
	self:load("network_registration"):modify()
	self:load("changed_reg_time"):modify()
	self:load("lastreg_timer"):modify()

	self:load("do_switch_result")

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
