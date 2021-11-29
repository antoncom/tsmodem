
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
		input = "Правило переключения Сим-карты, если баланс ниже минимума",
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

	uci_balance_min = {
		source = {
			model = "uci",
			config = "tsmodem",
			section = "uci_section",
			option = "balance_min"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ( "uci_balance_min" == "" or tonumber("uci_balance_min") == nil ) then return "30" else return "uci_balance_min" end ]]
		}
	},

	uci_timeout_bal = {
		source = {
			model = "uci",
			config = "tsmodem",
			section = "uci_section",
			option = "timeout_bal"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = [[ if ( "uci_timeout_bal" == "" or tonumber("uci_timeout_bal") == nil ) then return "999" else return "uci_timeout_bal" end ]]
		}
	},

	uci_bal_unit = {
		source = {
			model = "uci",
			config = "tsmodem",
			section = "uci_section",
			option = "balance_unit"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			-- ["1_formula"] = [[ if ("uci_bal_unit" == "") then return "ру." else return "uci_bal_unit" end ]]
		}
	},

	balance_time_previous = {
		input = "0",
		output = "0",
		subtotal = nil,
		modifier = {
			["1_logicfunc"] = 'if("balance_time" ~= "" and tonumber("balance_time") ~= nil) then return true else return false end',
            ["2_formula"] = 'return "balance_time"',
		}
	},

    balance_time = {
		source = {
			model = "tsmodem.driver",
			method = "balance",
			param = "time"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'if("balance_time" == "" or tonumber("balance_time") == nil) then return "0" else return "balance_time" end'
        }
	},

	event_datetime = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'return(os.date("%Y-%m-%d %H:%M:%S", tonumber("balance_time")))'
		}
	},


	sim_balance = {
		source = {
			model = "tsmodem.driver",
			method = "balance",
			param = "value"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
            ["1_formula"] = 'if("sim_balance" == "" or tonumber("sim_balance") == nil) then return "-" else return "sim_balance" end',
		}
	},

	sim_balance_ussd_response = {
		source = {
			model = "tsmodem.driver",
			method = "balance",
			param = "comment"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
            --["1_logicfunc"] = 'if("sim_balance_ussd_response" ~= "") then return true else return false end',
			["2_ui-update"] = {
				param_list = { "sim_balance_ussd_response", "sim_id" }
			},
		}
	},

    lowbalance_timer = {
		input = "",
		output = "",
		subtotal = nil,
        modifier = {
			["1_logicfunc"] = [[ if tonumber("sim_balance") ~= nil then return true else return false end ]],
            ["2_formula"] = 'if (tonumber("sim_balance") < tonumber("uci_balance_min")) then return( tostring(os.time() - tonumber("balance_time")) ) else return("0") end ',
			["3_ui-update"] = {
				param_list = { "lowbalance_timer", "sim_id" }
			},
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
				and ( tonumber("balance_time") > 0 )
				and ( "sim_balance" ~= "-" )
				and ( (tonumber("sim_balance") ~= nil) and (tonumber("sim_balance") < tonumber("uci_balance_min")) )
                and ( tonumber("lowbalance_timer") > tonumber("uci_timeout_bal") )
			) then return "begin" else return "" end ]],
			["2_ui-update"] = {
				param_list = { "event_switch_state" }
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
				and ( tonumber("balance_time") > 0 )
				and ( "sim_balance" ~= "-" )
				and ( (tonumber("sim_balance") ~= nil) and (tonumber("sim_balance") < tonumber("uci_balance_min")) )
                and ( tonumber("lowbalance_timer") > tonumber("uci_timeout_bal") )
			) then return true else return false end ]],
			["2_ui-update"] = {
				param_list = { "do_switch_result" }
			},
		}
	},

	event_is_new = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
			["1_formula"] = 'if("balance_time_previous" ~= "balance_time") then return "true" else return "false" end',
			["2_ui-update"] = {
				param_list = { "balance_time_previous", "balance_time" }
			},
		}
	},

	ussd_command = {
		source = {
			model = "tsmodem.driver",
			method = "balance",
			param = "command"
		},
		input = "",
		output = "",
		subtotal = nil,
		modifier = {

		}
	},


	ui_balance = {
		input = "",
		output = "",
		subtotal = nil,
		modifier = {
	--		["1_logicfunc"] = [[ if ( "event_is_new" == "true" )
	--						then return true else return false end ]],

			["2_ui-update"] = {
				param_list = { "sim_id", "sim_balance", "event_datetime", "balance_time" }
			}
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
	self:load("uci_balance_min"):modify()
	self:load("uci_timeout_bal"):modify()

	self:load("balance_time_previous"):modify()
	self:load("balance_time"):modify()

	self:load("event_datetime"):modify()
	self:load("sim_balance"):modify()

	self:load("sim_balance_ussd_response"):modify()

	self:load("lowbalance_timer"):modify()
	self:load("event_switch_state"):modify()
	self:load("do_switch_result"):modify()

	self:load("event_is_new"):modify()
	self:load("ussd_command"):modify()
	self:load("ui_balance"):modify():clear()

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
