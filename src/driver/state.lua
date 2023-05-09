
local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmodem.driver.util"
local CREG_STATE = require "tsmodem.constants.creg_state"


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
-- It helps to make Journal records in Web UI
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
                local sim_id_settings = msg["sim_id"] or "empty"
                local ok, err, sim_id = state:get("sim", "value")
                local resp = {}

                -- clear state for balance
                --state:update("balance", "", "", "")

                if(sim_id_settings == sim_id) then
                    local provider_id = get_provider_id(sim_id)

                    --local ussd_command = string.format("AT+CUSD=2,%s,15\r\n", uci:get(state.modem.config_gsm, provider_id, "balance_ussd"))
                    local ussd_command = string.format("AT+CUSD=2\r\n")
                    if (state.modem.debug and (state.modem.debug_type == "balance" or state.modem.debug_type == "all")) then print("----->>> Cancel USSD session before start new one: "..ussd_command) end
                    state:update("balance", "", ussd_command, uci:get(state.modem.config_gsm, provider_id, "balance_last_message"))
                    local chunk, err, errcode = U.write(state.modem.fds, ussd_command)

                    ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(state.modem.config_gsm, provider_id, "balance_ussd"))
                    state.modem.last_balance_request_time = os.time() -- Do it each time USSD request runs
                    state:update("balance", "", ussd_command, uci:get(state.modem.config_gsm, provider_id, "balance_last_message"))
                    if (state.modem.debug and (state.modem.debug_type == "balance" or state.modem.debug_type == "all")) then print("----->>> Do USSD request: "..ussd_command) end
                    local chunk, err, errcode = U.write(state.modem.fds, ussd_command)

                    resp = {
                        ["ussd_command"] = ussd_command,
                        ["chunk"] = chunk,
                        ["err"] = err,
                        ["errcode"] = errcode
                    }
                else
                    resp = {
                        ["error"] = string.format("[sim_id]=%s parameter doesn't match current modem state [sim]=%s", sim_id_settings, sim_id)
                    }
                end

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
                state:update("reg", CREG_STATE["SWITCHING"], "AT+CREG?", "")

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
                if (state.modem.debug and (state.modem.debug_type == "ping_update" or state.modem.debug_type == "all")) then
                	print(string.format('PING_UPDATE: ubus call tsmodem.driver ping_update ' .. "'" .. '{"sim_id":"%s","host":"%s","value":"%s"}' .. "'" .. ' &> /dev/null', msg["sim_id"], msg["host"], msg["value"]))
                end

                local resp = {}
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
                            if (state.modem.debug and (state.modem.debug_type == "ping" or state.modem.debug_type == "all")) then print("PING says: ","UBUS", tostring(state.timer.interval.ping).."ms", value, "","","","Note: ping.sh do the job.") end
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

        send_at = {
            function(req, msg)
                local resp = {}
                if msg["command"] then
                    if(state.modem:is_connected(state.modem.fds)) then
                        local chunk, err, errcode = U.write(state.modem.fds, msg["command"] .. "\r\n")
                        if err then
                            resp["at_answer"] = "tsmodem [state.lua]: Error of sending AT to modem."
                        else
                            if (state.modem.automation == "stop") then
                                resp["at_answer"] = "UBUS will notify subscribers of tsmodem.driver object with the AT answer."
                            else
                                resp["note"] = "UBUS will NOT notify subscribers with AT answer as tsmodem.driver automation is [" .. state.modem.automation .. "]"
                            end
                        end
                    end
                else
                    resp["at_answer"] = "Enter AT command like this " .. "'{" .. '"command": "AT+CSQ"' .. "}'"
                end
                state.conn:reply(req, resp);
            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        send_stm_at = {
            function(req, msg)
                local resp = {}
                local stm_comm = ""
                local send_only_if_new_command = ""
                local _, _, previous_comm = state:get("stm32", "command")

                if msg["sub_sys"] and msg["param"] and msg["arg"] then
                    stm_comm = "~0:" .. msg["sub_sys"] .. "." .. msg["param"] .. "=" .. msg["arg"]
                    -- Send AT to STM only if new command is not equal new one
                    -- It helps to avoid LED over-blinking each time the command sent.
                    if state.stm.fds then
                        send_only_if_new_command = (stm_comm ~= previous_comm)
                        if send_only_if_new_command then
                            local status, value = state.stm:command(stm_comm)
                            if status == "OK" then
                                state:update("stm32", "OK", stm_comm, "")
                            end
                            resp["at_answer"] = string.format("[%s] done. Status: %s, value: %s.", stm_comm, status, value)
                        else
                            resp["at_answer"] = string.format("[%s] SKIPPED, as it was done recently.", stm_comm)
                        end
                    else
                        resp["at_answer"] = "STM port seems not connected."
                    end
                else
                    resp["at_answer"] = "Enter STM AT command like this " .. "'{" .. '"sub_sys": "LED", "param": "1", "arg": "f200,200,200,800"' .. "}'"
                end
                state.conn:reply(req, resp);
            end, {id = ubus.INT32, msg = ubus.STRING }
        },

        automation = {
            function(req, msg)
                if msg and msg["mode"] and msg["mode"] == "run" then
                    state.modem:run_automation()
                    resp = { mode = state.modem.automation }
                elseif msg and msg["mode"] and msg["mode"] == "stop" then
                    state.modem.stop_automation()
                    resp = { mode = state.modem.automation }
                else
                    resp = { mode = state.modem.automation }
                end

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
    elseif (param == "reg" and (newval == CREG_STATE["REGISTERED"] or newval == CREG_STATE["SWITCHING"])) then
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
        elseif (param == "reg" and (newval == CREG_STATE["REGISTERED"] or newval == CREG_STATE["SWITCHING"])) then
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
