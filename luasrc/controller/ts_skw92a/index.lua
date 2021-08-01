module("luci.controller.ts_skw92a.index", package.seeall)

local config = "tsmodem"
--local factory = "ts_skw92a"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local ubus = require "ubus"
local log = require "luci.model.tsmodem.util.log"



function index()
	if nixio.fs.access("/etc/config/ts_skw92a") then
		entry({"admin", "system", "sim_list"}, cbi("ts_skw92a/main"), "SIM карты", 30)
		entry({"admin", "system", "sim_list", "action"}, call("do_sim_action"), nil).leaf = true
	end
end


function do_sim_action(action, sim_id)
	local payload = {}
	util.perror(luci.http.formvalue("sim_data"))

	payload["sim_data"] = luci.jsonc.parse(luci.http.formvalue("sim_data"))
	local commands = {
		switch = function(sim_id, ...)
			util.perror("sim_id")
			util.perror(sim_id)
			local conn = ubus.connect()
			if not conn then
				error("do_sim_switch_action - Failed to connect to ubus")
			end
			local resp = conn:call("tsmodem.driver", "switch", {["sim_id"] = sim_id})
			util.perror("RESP")
			util.perror(resp)
--[[

			local old_state = tonumber(uci:get(config, sim_id, "state"))
			local new_state = (old_state + 1) % 2
			uci:set(config, sim_id, "state", new_state)
			uci:commit(config)
			]]
		end,
		edit = function(sim_id, payloads)
			-- apply settings.<sim_id>
			--[[
			local allowed_relay_options = util.keys(uci:get_all(config, "relay_prototype"))
			for key, value in pairs(payloads["sim_data"]) do
				if util.contains(allowed_relay_options, key) then
					uci:set(config, sim_id, key, value)
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
			--http.prepare_content("text/plain")
			--http.write("0")
		end
	}
	if commands[action] then
		commands[action](sim_id, payload)
		commands["default"]()
	end
end
