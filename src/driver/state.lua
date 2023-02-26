
local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmodem.driver.util"


local state = {}
state.conn = nil      -- Link to UBUS
state.ubus_methods = nil

state.modem = nil
state.stm = nil
state.timer = nil

state.init = function(modem, stm, timer)
    state.modem = modem
    state.stm = stm
    state.timer = timer
    return state
end

--[[ STATE VARIABLES. UBUS IS USED TO GET ITS' VALUES ]]
state.queue_for = {"stm32", "usb", "reg", "netmode", "provider_name"}

state.stm32 = {}
state.stm32[1] = {
	command = "",
	value = "",					-- 0 / 1 / OK / ERROR
	time = "",
	unread = ""
}

state.reg = {}
state.reg[1] = {
	command = "",
	value = "",					-- 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7
	time = "",
	unread = ""
}

state.sim = {}
state.sim[1] = {
    command = "~0:SIM.SEL=?",
	value = "",					-- 0 / 1
	time = "",
	unread = ""
}

state.signal = {}
state.signal[1] = {
	command = "AT+CSQ",
	value = "",					-- 0..31
	time = "",
	unread = "true"
}


state.balance = {}
state.balance[1] = {
	command = "",
	value = "",
	time = "",
	unread = ""
}

state.usb = {}
state.usb[1] = {
	command = "", 				-- /dev/ttyUSB open  |  /dev/ttyUSB close
	value = "",					-- connected / disconnected
	time = "",
	unread = ""
}

state.netmode = {}
state.netmode[1] = {
	command = "", 				-- AT+.... __TODO__
	value = "",					-- _TODO__
	time = "",
	unread = "true"
}

state.provider_name = {}
state.provider_name[1] = {
	command = "",
	value = "",
	time = "",
	unread = ""
}

state.ping = {}
state.ping[1] = {
	command = "",
	value = "",
	time = "",
	unread = ""
}

state.switching = {}
state.switching[1] = {
	command = "",
	value = "",          -- true or false
	time = "",
	unread = ""
}


local ubus_methods = {
    ["tsmodem.driver"] = {
        reg = {
            function(req, msg)
                local resp = makeResponse("reg")
                state.conn:reply(req, resp);
            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        sim = {
            function(req, msg)
                local resp = makeResponse("sim")
                state.conn:reply(req, resp);
            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        signal = {
            function(req, msg)
                local resp = makeResponse("signal")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        balance = {
            function(req, msg)
                local resp = makeResponse("balance")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        do_request_ussd_balance = {
            function(req, msg)
                local sim_id_settings = msg["sim_id"]
                local ok, err, sim_id = state:get("sim", "value")
                if(sim_id_settings == sim_id) then
                    local provider_id = get_provider_id(sim_id)
                    local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(state.modem.config_gsm, provider_id, "balance_ussd"))
                    state.modem.last_balance_request_time = os.time() -- Do it each time USSD request runs

                    state:update("balance", "", ussd_command, uci:get(state.modem.config_gsm, provider_id, "balance_last_message"))
                    local chunk, err, errcode = U.write(state.modem.fds, ussd_command)
                end
                local resp = {}

                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        usb = {
            function(req, msg)
                local resp = makeResponse("usb")
                state.conn:reply(req, resp);
            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        stm32 = {
            function(req, msg)
                local resp = makeResponse("stm32")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        netmode = {
            function(req, msg)
                local resp = makeResponse("netmode")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        provider_name = {
            function(req, msg)
                local resp = makeResponse("provider_name")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        ping = {
            function(req, msg)
                local resp = makeResponse("ping")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        do_switch = {
            function(req, msg)
                local resp = {
    				command = "do_switch",
    				value = "false",
    				time = "",
    				unread = "",
    				comment = ""
    			}

                local switch_already_started = state:get("switching", "value")
                state:update("switching", "true", "", "")

                if (switch_already_started == "true") then
                    resp.value = "false"
                else
                    state.timer.SWITCH_1:set(state.timer.switch_delay["1_MDM_UNPOLL"])
                    resp.value = "true"
                end
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        ping_update = {
            function(req, msg)
                print("===========")
                util.perror("MODEM: %s, %s, %s", host, value, sim_id)
                if msg["host"] and msg["value"] and msg["sim_id"] then
                    local host   = msg["host"]
                    local value  = msg["value"]
                    local sim_id = tostring(msg["sim_id"])

                    if value == "1" or value == "0" then
                        local _,_,active_sim_id = state:get("sim", "value")
                        if not (sim_id == "1" or sim_id == "0") then
                            resp = { msg = "Param [sim_id] has to be 0 or 1. Nothing was done. "}
                        elseif sim_id == active_sim_id then
                            state:update("ping", value, "ping "..host, "updated via ubus call 'ping_update'")
                            if (state.modem.debug and state.modem.debug_type == "ping" or state.modem.debug_type == "all") then print("PING says: ","UBUS", tostring(state.timer.interval.ping).."ms", value, "","","","Note: ping.sh do the job.") end
                            resp = { msg = "ok" }
                        elseif sim_id ~= active_sim_id and (sim_id == "0" or sim_id == "1") then
                            resp = { msg = "Active sim was switched by user or automation rules. So 'ping_update' doesn't affect this time." }
                        end
                    else
                        resp = { msg = "Param [value] has to be 0 or 1. Nothing was done. "}
                    end
                else
                    resp = { msg = "[host], [value] and [sim_id] are required params. Nothing was done." }
                end

                state.conn:reply(req, resp);
            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        switching = {
            function(req, msg)
                local resp = makeResponse("switching")
                state.conn:reply(req, resp);

            end, {id = ubus.INT32, msg = ubus.STRING }
        },
    }
}

function state:make_ubus()
	state.conn = ubus.connect()
	if not state.conn then
		error("tsmodem: Failed to connect to ubus")
	end

	-- Сделать перебор очереди статусов, проверяя параметр "unread"
	-- и выдавать до тех пор пока unread==true
	function getFirstUnread(name)
		local n = #state[name]
		if n > 0 then
			for i=1, #state[name] do
				if state[name][i].unread == "true" then
					return state[name][i]
				end
			end
			-- If no unread states then return the last one.
            -- if name == "signal" then
            --     print("+++++", state[name][n].time, #state[name])
            -- end
			return state[name][n]
		end
		return {}
	end

	function makeResponse(name)
		local r, resp = {}, {}
		local n = #state[name]
		if (n > 0) then
			r = getFirstUnread(name)
			resp = util.clone(r)
			r["unread"] = "false"
		else
			resp = {
				command = "",
				value = "",
				time = "",
				unread = "",
				comment = ""
			}
		end
		return resp
	end

    state.conn:add( ubus_methods )
    state.ubus_methods = ubus_methods
end

--[[ For thouse params where queue of state is required ]]
--[[ see state.queue_for table to define the param names which need queue ]]
function state:update_queue(param, value, command, comment)
	local newval = tostring(value)

	local n = #state[param]

	if (n == 0) then
		local item = {
			["command"] = command,
			["value"] = newval,
			["time"] = tostring(os.time()),
			["unread"] = "true",
			["comment"] = comment
		}
		state[param][1] = util.clone(item)
	elseif (n >= 1) then
		if(state[param][n].value ~= newval or state[param][n].command ~= command) then
			local item = {
				["command"] = command,
				["value"] = newval,
				["time"] = tostring(os.time()),
				["unread"] = "true",
				["comment"] = comment
			}
			state[param][n+1] = util.clone(item)
			if n > 5 then
				table.remove(state[param], 1)
			end
		--[[ Update last time of succesful registration state ]]
		elseif (param == "reg" and (newval == "1" or newval == "7")) then
			state["reg"][n].time = tostring(os.time())
		--[[ Update time of last balance ussd request if balance's value is not changed ]]
        elseif (param == "balance") then
		    state["balance"][n].time = tostring(os.time())
		--[[ Update time of last successful ping ]]
		elseif (param == "ping") and value == "1" then
			state["ping"][n].time = tostring(os.time())
		end
	end
end

function state:update(param, value, command, comment)
    local newval = tostring(value)

    if (util.contains(state.queue_for, param)) then
        state:update_queue(param, value, command, comment)
    else
        local n = #state[param]
        if (n == 0) then
    		local item = {
    			["command"] = command,
    			["value"] = newval,
    			["time"] = tostring(os.time()),
    			["unread"] = "true",
    			["comment"] = comment
    		}
    		state[param][1] = util.clone(item)
        else
            local _,_,oldval =state:get(param, "value")
            local _,_,oldcomm = state:get(param, "command")
            if(oldval ~= newval or oldcomm ~= command) then
                local item = {
                    ["command"] = command,
                    ["value"] = newval,
                    ["time"] = tostring(os.time()),
                    ["unread"] = "true",
                    ["comment"] = comment
                }
                state[param][1] = util.clone(item)
            --[[ Update last time of succesful registration state ]]
    		elseif (param == "reg" and (newval == "1" or newval == "7")) then
    			state["reg"][1].time = tostring(os.time())
            --[[ Update last time when signal was Ok ]]
            elseif (param == "signal") then
                state["signal"][1].time = tostring(os.time())
    		--[[ Update time of last balance ussd request if balance's value is not changed ]]
    		elseif (param == "balance") then
    			state["balance"][1].time = tostring(os.time())
    		--[[ Update time of last successful ping ]]
    		elseif (param == "ping") and value == "1" then
    			state["ping"][1].time = tostring(os.time())
    		end
        end
    end
end

function state:get(var, param)
	local value = ""
	local v, p = tostring(var), tostring(param)
	if state[v] and (#state[v] > 0) and state[v][#state[v]][p] then
		value = state[v][#state[v]][p]
		return true, "", value
	else
		return false, string.format("State Var '%s' or Param '%s' are not found in list of state vars.", v, p), value
	end
end


return state
