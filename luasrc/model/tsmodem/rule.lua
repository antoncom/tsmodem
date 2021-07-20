
local bit = require "bit"
local lpeg = require "lpeg"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local uloop = require "uloop"


local rule = {}
local rule_setting = {
	name = "Переключить если не в сети",
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
			ready = false
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
			ready = false
		},
		modifier = {
			["1_parser"] = "tsmodem.parser.creg",
		}
	}
}



function rule:make_ubus()
	self.conn = ubus.connect()
	if not self.conn then
		error("rule:make_ubus() - Failed to connect to ubus")
	end

	local ubus_objects = {
		["tsmodem.rule"] = {
			list = {
				function(req, msg)
					local rule_list = {}
					-- TODO create a list of all rules, when the "group rules" functionality will be done
					rule_list["name"] = self.setting.name
					log("RULE_LIST", rule_list)
					--------------------------------
					self.conn:reply(req, rule_list);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			status = {
				function(req, msg)
					-- If "target.value" of every variable was populated
					-- then return "OK", otherwise "NOTOK"
					--------------------------------
					self.conn:reply(req, {status = "OK"});
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			value = {
				function(req, msg)
					-- Return all variables' target.value
					--------------------------------
					local resp = { 
						name = self.setting.name,
						action = '',
						sim_id = self.setting.sim_id.target.value,
						is_reg = self.setting.is_reg.target.value
					}
					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
	    	-- You get notified when someone subscribes to a channel
			__subscriber_cb = function( subs )
				print("RULE - total subs: ", subs )
			end
		}
	}
	self.conn:add( ubus_objects )
	self.ubus_objects = ubus_objects
end


function rule:make()
	-- Populate variables from their source
	-- During this process, apply logicfunc and formulas
	-- Run infinit loop to repeat again

	-- Populate vars
	self:populate(self.setting.sim_id)
	self:populate(self.setting.is_reg)
	self:populate(self.setting.action)

end

function rule:populate(varlink)
	local ubus_obj = varlink.source.model
	local command = ''
	local body = {}

	-- Add params to UBUS call
	if(varlink.source.params) then
		for i, param in varlink.source.params do
			body[param] = rule.setting[param] and rule.setting[param].target.value
		end
	end

	-- Choose UBUS method
	if(varlink.source.proto == "CUSTOM") then
		command = varlink.source.command

	else if(util.contains({"AT", "STM32"}, varlink.source.proto)) then
		command = varlink.source.proto
		body["command"] = varlink.source.command
	end
		
	-- Call UBUS
	local resp = self.conn:call(ubus_obj, command, body)

	varlink.target.value = resp[varlink.source.command]
	varlink.target.value = rule:modify(varlink)
	varlink.target.ready = true
	print(varlink.id .. ".target.value = ", varlink.target.value)
	
end

function rule:modify(varlink)
	local modifier = varlink.modifier
	for name, val in util.kspairs(modifier) do

		if(name:sub(3) == "formula") then
			-- parse formula, and execute
			local formula = val
			--local luacode = "return(" .. string.gsub(formula, varlink.id, varlink.target.value) .. ")"
			local luacode = string.format("return(%s)", string.gsub(formula, varlink.id, varlink.target.value))
			local result = loadstring(luacode)()
			print("SIM_ID after formula:", result)
			return result
		end

		if(name:sub(3) == "parser") then
			local parser = val
			local result = require(parser):match(varlink.target.value)
			return  result
		end

		if(name:sub(3) == "logicfunc") then
			-- parse logicfunc and execute
			-- return result
		end
	end
end

-- NOT USED YET
function rule:get_subscriber(event, varlink)
	self.subscribers = {
		["AT-speeking"] = {
			notify = function(msg, name)
				if((name == event) and (varlink.target.value ~= "")) then
					varlink.target.value = msg
					-- TODO apply parser here
				end
			end
		},
		["nothing"] = {
			notify = function(msg, name)
				-- Do nothing
				-- This subscribe function is use to cancel any subscription
			end
		}
	}
	return self.subscribers[event]
end


function rule:get_autorefresh(varlink)
	local timer
	local interval = varlink.modifier["autorefresh"] or 2000
	self.auto_refreshers = {
		["is_reg"] = function(t)
			timer:set(interval)
		end
	}
	timer = uloop.timer(t)
	timer:set(interval)
end

local metatable = { 
	__call = function(table)
		table.setting = rule_setting
		table:make_ubus()

		uloop.init()

		local timer
		function t()
			print("Fresh and Make")
			table:fresh()
			table:make()
			timer:set(1000)
		end
		timer = uloop.timer(t)
		timer:set(1000)


		uloop.run()
		table.conn:close()
		return table
	end
}
setmetatable(rule, metatable)
rule()