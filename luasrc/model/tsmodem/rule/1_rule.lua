
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local ubus = require "ubus"

local modifier = require "modifier.main"
local logicfunc = require "modifier.logicfunc"


local reg_timeout = 120

local rule = {} 
rule.ubus = {}
rule.subscribed = false

local rule_setting = {
	title = {
		source_value = "Переключить если не в сети",
		target_value = ""
	},

	lastreg_time = {
		source_value = tostring(os.time()),
		target_value = tostring(os.time()),
		target_modifier = {
			["1_formula"] = 'if("network_registration" == "1") then return(tostring(os.time())) else return("lastreg_time") end'
		}
	},

	lastreg_timer = {
		source_value = "0",
		target_value = "0",
		target_modifier = {
			["1_formula"] = 'return(tostring(os.time() - tonumber("lastreg_time")))',
			["2_ui-update"] = {
				param_list = { "lastreg_timer" }
			}
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
			-- Get current sim id only if system is not in switching process
			["1_logicfunc"] = [[ if (
				("action" ~= "switching-in-progress")
			) then return true end return false
			]],
			-- Calculate in-active sim id to switch to
			["2_formula"] = 'if("sim_id_switch_to" == "1") then return "0" elseif("sim_id_switch_to" == "0") then return "1" end'
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
			["2_formula"] = [[ if (
				("action" == "status-disconnected")
			) then return "7" else return "network_registration" end ]],
			["3_ui-update"] = {
				param_list = { "network_registration", "sim_id" }
			}
		}
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
			["1_logicfunc"] = [[ if ( 
					( "network_registration" ~= "1" )
				and ( tonumber("lastreg_timer") > ]] .. tostring(reg_timeout) .. [[ )
			) then return true else return false end ]],
			-- Reset "action" when modem connected
			-- TODO ["2_subscribe"] = "It's realized now below - in the 'subscribe_once() method' "
		}
	},

}

function rule:logicfunc(varname)
	return logicfunc:logicfunc(varname, self.setting)
end

function rule:modify(varname)
	return modifier:modify(varname, self.setting)
end

function rule:populate(varname)
	local varlink = self.setting[varname]
	if(varlink.source) then
		local ubus_obj = varlink.source.model or false
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
end


function rule:make()

	-- Populate self-generated and constants

	self:modify("title")

	-- Populate vars

	self:populate("sim_id")
--	self.setting.sim_id.source_value = self.setting.sim_id.target_value or ""
	self:modify("sim_id")

	self:populate("sim_id_switch_to")
--	self.setting.sim_id_switch_to.source_value = self.setting.sim_id_switch_to.target_value or ""
	self:modify("sim_id_switch_to")
	
	self:populate("network_registration")
--	self.setting.network_registration.source_value = self.setting.network_registration.target_value or ""
	self:modify("network_registration")

	self.setting.lastreg_time.source_value = self.setting.lastreg_time.target_value or ""
	self:modify("lastreg_time")

	self.setting.lastreg_timer.source_value = self.setting.lastreg_timer.target_value or ""
	self:modify("lastreg_timer")


	-- Do action

	self:populate("action")
	--self.setting.action.source_value = self.setting.action.target_value or ""
	self:modify("action")

end

function rule:subscribe_once()
	if not self.subscribed then

		-- Reset "action" state if modem reconnected

		self.conn:subscribe("tsmodem.driver", {
			notify = function(data, proto)
				if(proto == "STM32") then

					local command = data["command"] or ""
					local response = data["response"] or ""

					if(command == "GSM-attach" and response == "DISCONNECTED") then

						--print("RESET ON DISCONNECTED")

						self.setting.lastreg_time.source_value = tostring(os.time())
						self.setting.lastreg_time.target_value = tostring(os.time())

						self.setting.lastreg_timer.source_value = "0"
						self.setting.lastreg_timer.target_value = "0"

						self.setting.action.source_value = "status-disconnected"
						self.setting.action.target_value = "status-disconnected"

					end

					if(command == "GSM-attach" and response == "CONNECTED") then

						self.setting.action.source_value = ""
						self.setting.action.target_value = ""

					end
				end
			end
		})
		self.subscribed = true
	end
end

local metatable = { 
	__call = function(table, parent)
		table.setting = rule_setting

		table.ubus = parent.ubus_object
		table.conn = parent.conn
		table:subscribe_once()	
		table:make()		

		return table
	end
}
setmetatable(rule, metatable)

return rule