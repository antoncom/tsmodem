
local lpeg = require "lpeg"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"

local ubus = require "ubus"

local rule = {}
rule.ubus = {}

local rule_setting = {
	name = "Переключить если не в сети",
	id = "1_rule",
	action = {
		id = "action",
		source = {
			model = "tsmodem.driver",
			proto = "CUSTOM",
			command = "switch",
			params = {"sim_id"}
		},
		target = {
			value = "",
			ready = false
		},
		modifier = {
			["1_logicfunc"] = "if (is_reg == 0) then return true else return false end",
			["2_event"] = {
				ubus_name = "tsmodem.rule",
				event_name = "sim_card_switched",
				param_list = { "sim_id" },
			}
		}
	},
	sim_id = {
		id = "sim_id",
		source = {
			model = "tsmodem.driver",
			proto = "STM32",
			command = "~0:SIM.SEL=?"
		},
		target = {
			value = "",
			ready = false
		},
		modifier = {
			["1_formula"] = "return(sim_id + 1 - 2 * sim_id / 1)"
		}
	},
	is_reg = {
		id = "is_reg",
		source = {
			model = "tsmodem.driver",
			proto = "AT",
			command = "AT+CREG?"
		},
		target = {
			value = "",
			ready = false
		},
		modifier = {
			["1_parser"] = "tsmodem.parser.creg",
			["2_formula"] = "if (is_reg == 1) then return '1' else return '0' end",
			["3_event"] = {
				ubus_name = "tsmodem.rule",
				event_name = "is_reg_monitor",
				param_list = { "is_reg" },
			}
		}
	}
}


function rule:populate(varlink)
	local ubus_obj = varlink.source.model
	local command = ''
	local body = {}

	-- Add params to UBUS call
	if(varlink.source.params) then
		for _, param in pairs(varlink.source.params) do
			body[param] = rule.setting[param] and rule.setting[param].target.value
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
	local resp = ''
	if(rule:logic(varlink) == true) then
		resp = self.conn:call(ubus_obj, command, body)
		varlink.target.value = resp[varlink.source.command]

	-- Apply modifiers
		rule:modify(varlink)
		varlink.target.ready = true
	end
end

-- Logic modifier realization
function rule:logic(varlink) --[[
	Substitute values instead variables
	and check logic expression
	]]
	local modifier = varlink.modifier or {}
	local result = true
	local logic, luacode = '', ''

	for mdf_name, mdf_val in util.kspairs(modifier) do
		if(mdf_name:sub(3) == "logicfunc") then
			logic = mdf_val
			-- Iterate all variables and substitute its values to logic function
			for varname, _ in pairs(self.setting) do
				if(self.setting[varname].target) then
					logic = logic:gsub(varname, self.setting[varname].target.value)
				end
			end
			local luacode = logic
			result = loadstring(luacode)() or false
			break
		end
	end
	return result	
end


function rule:modify(varlink) --[[
	Apply modifiers
	-------------]]
	local modifier = varlink.modifier or {}
	for name, val in util.kspairs(modifier) do
		if(name:sub(3) == "formula") then
			-- parse formula, and execute
			local formula = val
			print("FORMULA", varlink.id)
			log("VALUE", varlink.target.value)
			local luacode = string.gsub(formula, varlink.id, varlink.target.value)
			varlink.target.value = loadstring(luacode)() or ""
		end

		if(name:sub(3) == "parser") then
			local parser = val
			varlink.target.value = require("luci.model." .. parser):match(varlink.target.value) or ""
		end

		if(name:sub(3) == "event") then
			local event_name, ubus_name, params_list = '', '', varlink.modifier[name].param_list
			ubus_name = varlink.modifier[name].ubus_name
			event_name = varlink.modifier[name].event_name

			-- Prepare params to send with notification for ubus
			local params = {}
			for i=1, #params_list do
				params[params_list[i]] = self.setting[params_list[i]].target.value
			end

			self.conn:notify(self.ubus[ubus_name].__ubusobj, event_name, params)
		end

	end
end

function rule:make()
	-- Populate variables from their source
	-- During this process, apply logicfunc and other modifiers

	-- Populate vars and apply modifiers
	self:populate(self.setting.sim_id)
	self:populate(self.setting.is_reg)
	-- Do action
	self:populate(self.setting.action)

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