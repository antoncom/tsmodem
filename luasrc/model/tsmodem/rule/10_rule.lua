
local lpeg = require "lpeg"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local sys  = require "luci.sys"


local ubus = require "ubus"

local PROTO = "AT"
local EVENT_SOURCE_NAME = "Модем"
local EVENT_TITLES = {
	["AT+CREG?"] 		= "Изменился статус регистрации в сети",
	["AT+CSQ"] 			= "Изменился уровень сигнала БС",
	["___todo___"] 		= "Остаток средств ниже нормы"
}

local rule = {}
rule.ubus = {}
rule.subscribed = false


local rule_setting = {
	title = {
		src_value = "Правило журналирования событий Модема",
		trg_value = "",
	},

	id = {
		src_value = "10_rule",
		trg_value = "",
	},

	event_datetime = {
		src_value = "",
		trg_value = "",
		modifier = {
			["1_formula"] = 'return(os.date("%Y-%m-%d %H:%M:%S"))'
		}
	},

	event_name = {
		src_value = "",
		trg_value = "",
	},

	event_command = {
		src_value = "",
		trg_value = "",
	},

	event_command_old = {
		src_value = "",
		trg_value = "",
		modifier = {
			["1_formula"] = 'return("event_command")'
		}
	},

	event_response = {
		src_value = "",
		trg_value = "",
		modifier = {
			["1_parser"] = "tsmodem.parser.creg"
		}
	},

	event_response_old = {
		src_value = "",
		trg_value = "",
		modifier = {
			["1_formula"] = 'return("event_response")'
		}

	},


	journal = {
		src_value = "",
		trg_value = "",
		modifier = {
			["1_logicfunc"] = 'if not ("event_command" == "event_command_old" and "event_response" == "event_response_old") then return true else return false end',
			["2_formula"] = [[return({ 
					datetime = "event_datetime", 
					name = "event_name", 
					source = "Модем", 
					command = "event_command", 
					response = "event_response" 
				})]],
			["3_ui-update"] = {
				param_list = { "journal" }
			}
		}
	}
	
}



function rule:modify(varname) --[[
	Apply modifiers to the target value
	---------------------------------]]
	local varlink = self.setting[varname]

	-- Firstly, we put unmodified source data to target

	varlink.trg_value = varlink.src_value

	-- If modifiers are existed, then modify the target value

	local modifier = varlink.modifier or {}
	for name, val in util.kspairs(modifier) do

		if "formula" == name:sub(3) then
			local formula = val

			-- Replace varnames with actual values

			local luacode = (function(chunk) 
				for varname, _ in pairs(self.setting) do
					if(type(self.setting[varname].trg_value) == "string") then
						chunk = chunk:gsub('"' .. varname .. '"', '"' .. self.setting[varname].trg_value .. '"')
					end
				end
				return chunk
			end)(formula)
			luacode = string.gsub(luacode, varname, varlink.trg_value) or "return(false)"
			varlink.trg_value = loadstring(luacode)() or ""


		end

		if "parser" == name:sub(3) then
			local parser = val
			varlink.trg_value = require("luci.model." .. parser):match(varlink.trg_value) or "No parsing result"
		end

		if "ui-update" == name:sub(3) then
			local ui_data, param_list = '', varlink.modifier[name].param_list or {}

			-- Prepare params to send to UI
			local params = {}
			for i=1, #param_list do
				params[param_list[i]] = self.setting[param_list[i]].trg_value
			end

			ui_data = util.serialize_json(params)
			sys.exec(string.format("echo '%s' > /tmp/wspipein.fifo", ui_data))
		end

	end
end


function rule:logic(varname) --[[
	Logicfunc modifier realization.
	Substitute values instead variables
	and check logic expression
	]]
	local modifier = self.setting[varname].modifier or {}
	local logic, result = '', true

	for name, value in util.kspairs(modifier) do
		if(name:sub(3) == "logicfunc") then
			logic = value

			for name, _ in pairs(self.setting) do
				if(type(self.setting[name].trg_value) == "string") then
					logic = logic:gsub('"' .. name .. '"', '"' .. self.setting[name].trg_value .. '"')
				end
			end
			print("LOGIC", logic)
			result = loadstring(logic)() or false
			break
		end
	end
	return result	
end


function rule:subscribe_once()
	if not self.subscribed then
		local possible_commands = util.keys(EVENT_TITLES)

		self.conn:subscribe("tsmodem.driver", {
			notify = function(data, proto)
				if(proto == PROTO) then
					local command = data["command"] or ""
					local response = data["response"] or "6"

					if(util.contains(possible_commands, command)) then

						-- Populate self-generated and constants

						for _, name in ipairs({"event_command_old", "event_response_old", "event_datetime", "title", "id"}) do
							self:modify(name)
						end

						-- Populate data on subscribtion

						self.setting.event_name.src_value = EVENT_TITLES[command]
						self:modify("event_name")
	

						self.setting.event_command.src_value = command
						self:modify("event_command")


						self.setting.event_response.src_value = response
						self:modify("event_response")

						-- Publish journal only if Logicfunc modifier returns True
						
						if(self:logic("journal") == true) then
							self:modify("journal")
						end

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
		

		return table
	end
}
setmetatable(rule, metatable)

return rule