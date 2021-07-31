
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"

local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local rule = {} 
rule.ubus = {}


local rule_setting = {
	title = {
		source_value = "Переключить если не в сети",
		target_value = ""
	},

	action = {
		source = {
			model = "tsmodem.driver",
			proto = "CUSTOM",
			command = "switch",
			params = {"sim_id_switch_to"}
		},
		source_value = "",
		target_value = "",
		target_modifier = {
			--["1_logicfunc"] = 'if ("network_registration" == "0") then return true else return false end',
			["1_logicfunc"] = 'return false',
		}
	},

	sim_id = {
		source = {
			model = "tsmodem.driver",
			proto = "STM32",
			command = "~0:SIM.SEL=?"
		},
		source_value = "",
		target_value = "",
	},

	sim_id_switch_to = {
		source = {
			model = "tsmodem.driver",
			proto = "STM32",
			command = "~0:SIM.SEL=?"
		},
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_formula"] = 'if("sim_id" == "1") then return "0" elseif(sim_id == 0) then return "1" end'
		}
	},

	network_registration = {
		source = {
			model = "tsmodem.driver",
			proto = "AT",
			command = "AT+CREG?"
		},
		source_value = "",
		target_value = "",
		target_modifier = {
			["1_parser"] = "tsmodem.parser.creg",
			["2_formula"] = 'if ("network_registration" == "") then return "4" else return "network_registration" end',
			["3_ui-update"] = {
				param_list = { "network_registration", "sim_id" }
			}
		}
	}
}

function rule:logicfunc(varname)
	return logicfunc:logicfunc(varname, self.setting)
end

function rule:modify(varname)
	return modifier:modify(varname, self.setting)
end

function rule:populate(varname)
	local varlink = self.setting[varname]
	local ubus_obj = varlink.source.model
	local command = ''
	local body = {}

	-- Add params to UBUS call
	if(varlink.source.params) then
		for _, param in pairs(varlink.source.params) do
			body[param] = rule.setting[param] and rule.setting[param].target_value
		end
	end

	-- Choose UBUS method
	if(varlink.source.proto == "CUSTOM") then
		command = varlink.source.command

	elseif(util.contains({"AT", "STM32"}, varlink.source.proto)) then
		command = varlink.source.proto
		body["command"] = varlink.source.command
	end
		
	-- Call UBUS only if 'logicfunc' modifier is absent or returns true
	if(rule:logicfunc(varname) == true) then

		-- We put the data got from source to "source_value"

		local resp = self.conn:call(ubus_obj, command, body)
		varlink.source_value = resp[varlink.source.command] or ""

		-- Before apply first modifier, we put unmodified source data to target

		varlink.target_value = varlink.source_value or ""
	end
end


function rule:make()

	-- Populate self-generated and constants

	self:modify("title")

	-- Populate vars

	self:populate("sim_id")
	self:modify("sim_id")
	
	self:populate("network_registration")
	self:modify("network_registration")

	-- Do action

	self:populate("action")
	self:modify("action")

end

local metatable = { 
	__call = function(table, parent)
		table.setting = rule_setting

		table.ubus = parent.ubus_object
		table.conn = parent.conn
		table:make()		

		return table
	end
}
setmetatable(rule, metatable)

return rule