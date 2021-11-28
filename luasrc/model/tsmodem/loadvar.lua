
--local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local uci = require "luci.model.uci".cursor()


local loadvar = {}
loadvar.cache_ubus = {}
loadvar.cache_uci = {}

function loadvar:clear()
	self.cache_ubus = nil
	self.cache_ubus = {}

	self.cache_uci = nil
	self.cache_uci = {}
end

local loadvar_metatable = {
	__call = function(loadvar_table, rule, varname)

		local varlink = rule.setting[varname]
		varlink.subtotal = nil

		if(rule:logicfunc(varname) == true) then
			--[[ Load from UCI ]]
			if(varlink.source and (varlink.source.model == "uci")) then

				local config = varlink.source.config
				local section = string.sub(varlink.source.section, 1)
				local option = string.sub(varlink.source.option, 1)

				local setting = rule.setting

				for name, _ in pairs(setting) do
					-- Substitute variable value if the variable's name contains uci section
					if(type(setting[name].output) == "string") then
						if name == section then
							section = section:gsub(name, setting[name].output)
						end
					end
					-- Substitute variable value if the variable's name contains uci option
					if(type(setting[name].output) == "string") then
						if name == option then
							option = option:gsub(name, setting[name].output)
						end
					end
				end

				local res = uci:get_all(config, section) or ""

				-- Save to cache for further using
				if (res and type(res) == "table") then
					loadvar_table.cache_uci[section] = res
					varlink.input = option and loadvar_table.cache_uci[section][option]
					--[[
					if(option) then
						varlink.input = string.format("%s", tostring(loadvar_table.cache_uci[section][option]))
					else
						varlink.input = ""
					end
					]]
					---------------------
				else
					varlink.input = varlink.input or ""
				end

--[[			if(varname == "uci_signal_min") then
					log(option, loadvar_table.cache_uci[section]["signal_min"])
				end
]]

			--[[ Load from UBUS ]]
			elseif (varlink.source and (varlink.source.model ~= "uci")) then
				local ubus_obj = varlink.source.model or ""
				local method = varlink.source.method
				local param = varlink.source.param
				if not loadvar_table.cache_ubus[method] then
					local variable = rule.conn:call(ubus_obj, method, {})
					loadvar_table.cache_ubus[method] = variable
				end
				varlink.input = param and loadvar_table.cache_ubus[method][param] or ""
				--[[
				if(param and loadvar_table.cache_ubus[method][param]) then
					varlink.input = string.format("%s", tostring(loadvar_table.cache_ubus[method][param]))
				else
					varlink.input = ""
				end
				]]
				------------

			end
		end

		-- Make function chaning like this:
		-- rule:load("title"):modify()
		---------------------=========
		local mdf = {}
		function mdf:modify()

			-- Apply modifiers only if Logic func returns true
			if(rule:logicfunc(varname) == true) then
				rule:modify(varname)
			end

			-- Make function chaning like this:
			-- rule:load("title"):modify():clear()
			------------------------------========

			local clr = {}
			function clr:clear()
				loadvar_table:clear()
			end

			local clear_metatable = {
				__call = function(clear_table)
					return clear_table
				end
			}

			setmetatable(clr, clear_metatable)
			return clr

		end
		local modify_metatable = {
			__call = function(modify_table)
				return modify_table
			end
		}
		setmetatable(mdf, modify_metatable)
		return mdf

	end
}

setmetatable(loadvar, loadvar_metatable)
return loadvar
