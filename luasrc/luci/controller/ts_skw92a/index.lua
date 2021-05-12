module("luci.controller.ts_skw92a.index", package.seeall)

local config = "ts_skw92a"
--local factory = "ts_skw92a"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"


function index()
	if nixio.fs.access("/etc/config/ts_skw92a") then
		entry({"admin", "system", "sim_list"}, cbi("ts_skw92a/main"), "SIM карты", 30)
		entry({"admin", "system", "sim_list", "action"}, call("do_sim_action"), nil).leaf = true
	end
end


function do_sim_action(action, sim_id)
	local payload = {}
	payload["sim_data"] = luci.jsonc.parse(luci.http.formvalue("sim_data"))
	local commands = {
		switch = function(relay_id, ...)
			--[[
			local old_state = tonumber(uci:get(config, relay_id, "state"))
			local new_state = (old_state + 1) % 2
			uci:set(config, relay_id, "state", new_state)
			uci:commit(config)
			]]
		end,
		edit = function(relay_id, payloads)
			-- apply settings.<relay_id>
			--[[
			local allowed_relay_options = util.keys(uci:get_all(config, "relay_prototype"))
			for key, value in pairs(payloads["sim_data"]) do
				if util.contains(allowed_relay_options, key) then
					uci:set(config, relay_id, key, value)
				end
				uci:commit(config)
			end
			-- apply settings.globals
			local allowed_global_options = util.keys(uci:get_all(config, "globals"))
			for key, value in pairs(payloads["globals_data"]) do
				if util.contains(allowed_global_options, key) then
					if type(value) == "table" then
						uci:set_list(config, "globals", key, value)
					else
						uci:set(config, "globals", key, value)
					end
				end
				uci:commit(config)
			end
			]]
		end,
		default = function(...)
			http.prepare_content("text/plain")
			http.write("0")
		end
	}
	if commands[action] then
		commands[action](relay_id, payload)
		commands["default"]()
	end
end
