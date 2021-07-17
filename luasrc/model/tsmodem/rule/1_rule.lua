
local lpeg = require "lpeg"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"

local rule = {}
local rule_setting = {
	name = "Переключить если не в сети",
	action = {
		id = "action",
		source = {
			model = "tsmodem.driver",
			proto = "STM32",
			command = "~0:SIM.SEL=%_sim_id_%",
			params = {"sim_id"}
		},
		target = {
			value = "",
			state = false
		},
		modifier = {
			["1_logicfunc"] = "is_reg == 0"
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
			state = false
		},
		modifier = {
			["1_formula"] = "tonumber(sim_id) + 1 - 2 * tonumber(sim_id) / 1"
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
			state = false
		},
		modifier = {
			["1_parser"] = "tsmodem.parser.creg",
		}
	}
}



function rule:populate(varlink)
	local ubus_obj = varlink.source.model
	local resp = self.conn:call(ubus_obj, "get", { command = varlink.source.command, proto = varlink.source.proto })

	varlink.target.value = resp[varlink.source.command]
	varlink.target.value = rule:modify(varlink)
	print(varlink.id .. ".target.value = ", varlink.target.value)
	
end

function rule:modify(varlink)
	local modifier = varlink.modifier
	for name, val in util.kspairs(modifier) do

		if(name:sub(3) == "formula") then
			-- parse formula, and execute
			local formula = val
			local luacode = "return(" .. string.gsub(formula, varlink.id, varlink.target.value) .. ")"
			local result = loadstring(luacode)()
			print("SIM_ID after formula:", result)
			return result
		end

		if(name:sub(3) == "parser") then
			local parser = val
			local result = require("luci.model." .. parser):match(varlink.target.value)
			return  result
		end

		if(name:sub(3) == "logicfunc") then
			-- parse logicfunc and execute
			-- return result
		end
	end
end

function rule:make()
	-- Populate variables from their source
	-- During this process, apply logicfunc and formulas
	-- Run infinit loop to repeat again

	-- Populate vars
	self:populate(self.setting.sim_id)
	self:populate(self.setting.is_reg)
	--self:populate(self.setting.action)

end

function rule:fresh()
	-- Clear all values' target.value
	-- Then, in next loop make() will be run again
end

local metatable = { 
	__call = function(table)
		table.setting = rule_setting
		
		table.conn = ubus.connect()
		if not table.conn then
			error("rules() - Failed to connect ubus")
		end
		
		table:make()
		table.conn:close()

		return table
	end
}
setmetatable(rule, metatable)

return rule