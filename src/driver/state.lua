
-- Модуль состояний (методов) на шине UBUS.
-- Создаёт объект на шине UBUS.
-- Имеет функции update(), get() для работы с состояниями на шине UBUS.
-- Связан с другими модулями сервиса - см. .init()

local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"
local ubus = require "ubus"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmodem.driver.util"
require "tsmodem.util.pdu_encoder"
require "tsmodem.constants.lock_owners_debug"

local spec_V300_ch9 = require "tsmodem.spec.v300_ch9"
local clear_sms_storage = require "tsmodem.util.clear_sms_storage"


local state = {}
state.conn = nil      -- Link to UBUS
state.ubus_methods = nil
state.last_at_command = ""

state.modem = nil
state.timer = nil
state.notifier = nil

state.init = function(modem, timer, notifier)
    state.modem = modem
    state.timer = timer
    state.notifier = notifier
    return state
end

--[[ STATE VARIABLES. UBUS IS USED TO GET ITS' VALUES ]]
-- It helps to make Journal records in Web UI
state.queue_for = {"usb", "reg", "netmode", "provider_name"}

state.cpin = {
    command = "",
    value = "",                 -- "true" or "false" mean sim is inserted or not
    changed = "",
    updated = "",
    comment = ""
}

state.reg = {
    command = "",
    value = "",                 -- 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7
    changed = "",
    updated = "",
    comment = ""
}

state.signal = {
    command = "AT+CSQ",
    value = "",                 -- 0..31
    time = "",
    comment = ""
}

state.balance = {
    command = "",
    value = "",
    changed = "",
    updated = "",
    comment = ""
}

state.usb = {
    command = "",               -- /dev/ttyUSB open  |  /dev/ttyUSB close
    value = "",                 -- connected / disconnected
    changed = "",
    updated = "",
    comment = ""
}

state.netmode = {
    command = "",               
    value = "",                 
    changed = "",
    updated = "",
    comment = ""
}

state.provider_name = {
    command = "",
    value = "",
    changed = "",
    updated = "",
    comment = ""
}


local ubus_methods = {
    ["tsmodem.driver"] = {
        cpin = {
            function(req, msg)
                local resp = makeResponse("cpin")
                state.conn:reply(req, resp);
            end, {}
        },
        reg = {
            function(req, msg)
                local resp = makeResponse("reg")
                state.conn:reply(req, resp);
            end, {}
        },

        signal = {
            function(req, msg)
                local resp = makeResponse("signal")
                state.conn:reply(req, resp);

            end, {}
        },

        balance = {
            function(req, msg)
                local resp = makeResponse("balance")
                state.conn:reply(req, resp);

            end, {}
        },

        usb = {
            function(req, msg)
                local resp = makeResponse("usb")
                state.conn:reply(req, resp);
            end, {}
        },

        netmode = {
            function(req, msg)
                local resp = makeResponse("netmode")
                state.conn:reply(req, resp);

            end, {}
        },

        provider_name = {
            function(req, msg)
                local resp = makeResponse("provider_name")
                state.conn:reply(req, resp);

            end, {}
        },

        send_at = {
            function(req, msg)
                local resp = {}

                if_debug("send_at", "I've got AT command by UBUS: " .. luci.util.serialize_json(msg))

                if not msg["module_name"] then msg["module_name"] = "unknown" end
                if not state.modem.lock.is_owner_or_set_if_unlocked(msg["module_name"]) then
                    resp.status = "busy"
                    resp.msg = "tsmodem is busy"
                    state.conn:reply(req, resp)
                    return
                end

                if msg["command"] then
                    if(state.modem:is_connected(state.modem.fds)) then
                        if (msg["what-to-update"] == "balance") then
                            state.timer.BAL_TIMEOUT:set(state.timer.timeout["balance"]) -- clear balance state after timeout
                            if_debug("send_at", "AT ASK" .. tostring(msg) .. " Note: sends AT command to get balance and clear balance state if no AT-answer during " .. tostring(state.timer.timeout["balance"]/60000) .. " min.")
                        end

                        if(string.find(state.last_at_command, "AT%+CMGS") and string.find(state.last_at_command, "AT%+CMGS") > 0) then
                            local chunk, err, errcode = U.write(state.modem.fds, msg["command"] .. "\26")
                            state.last_at_command = ""
                            if_debug("send_at", "UBUS ASK " .. tostring(msg["command"]) .. "\26 SMS was sent")
                        else
                            local chunk, err, errcode = U.write(state.modem.fds, msg["command"] .. "\r\n")
                            state.last_at_command = msg["command"]
                            if_debug("send_at", "UBUS ASK " .. tostring(msg) .. " Note: sends AT command to the modem")
                        end

                        if err then
                            resp["at_answer"] = "tsmodem [state.lua]: Error of sending AT to modem."
                        else
                            resp["at_answer"] = "UBUS will notify subscribers of tsmodem.driver object with the AT answer."
                        end
                    end
                else
                    resp["at_answer"] = "Enter AT command like this " .. "'{" .. '"command": "AT+CSQ"' .. "}'"
                end
                resp["value"] = "true"
                state.conn:reply(req, resp);
            end, {command = ubus.STRING, ["what-to-update"] = ubus.STRING, module_name = ubus.STRING}
        },

        lock = {
            function (req, msg)
                local resp = {}
                if not msg["module_name"] then msg["module_name"] = "unknown" end
                        -- if_debug(" ")
                        -- if_debug("┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
                        -- if_debug('┃ Tsmodem is loclked by: [] ┃')
                        -- if_debug('┗━━━━━━━━━━━━━━━━━━━━━━━━━━┛')
                        -- if_debug("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
                        -- if_debug('┃ Type "tsmodem debug all" in a different shell ┃')
                        -- if_debug('┃ to see how the sim-card or network            ┃')
                        -- if_debug('┃ detecting process is going on..               ┃')
                        -- if_debug('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛')
                        -- if_debug(" ")
                if state.modem.lock.is_owner_or_set_if_unlocked(msg["module_name"]) then
                    resp.is_owner = true
                else
                    resp.is_owner = false
                end

                state.conn:reply(req, resp)
            end, { module_name = ubus.STRING }
        },

        unlock = {
            function (req, msg)
                if not msg["module_name"] then msg["module_name"] = "unknown" end
                local unlock_status, unlock_msg = state.modem.lock.unlock(msg["module_name"])
                if_debug("lock", "I'm unlocked by [" .. msg["module_name"] .. "] via UBUS. Status: [" .. tostring(unlock_status) .. "]. Msg: [" ..tostring(unlock_msg) .. "].", "bright_yellow")

                local resp = { unlock_status = unlock_status, msg = unlock_msg }
                state.conn:reply(req, resp)
            end, { module_name = ubus.STRING }
        },

        lock_status = {
            function (req, msg)
                local resp = {}
                resp.owner = state.modem.lock.owner
                resp.last_request_time = state.modem.lock.last_request_time
                state.conn:reply(req, resp)
            end, {}
        },

        -- [[ Clear all states ]]
        -- [[ e.g. when we save Sim-settings on the web UI]]
        clear_state = {
            function(req, msg)
                if_debug("UBUS ASK 'clear_state' " ..  tostring(msg) .. " Note: Clear states, e.g. when we save Sim-settings on the web UI")

                local resp = { res = "OK" }
                state:update("reg", "7", "", "")
                state:update("signal", "", "", "")
                state:update("provider_name", "", "", "")
                state:update("netmode", "", "", "")
                state:update("cpin", "", "", "")
                state:update("balance", "", "", "")


                if_debug("clear_state", "UBUS ANSWER " .. tostring(resp))


                state.conn:reply(req, resp);

            end, {}
        },

        clear_sms_storage = {
            function (req, msg)
                if_debug("clear_sms_storage", "clear_sms_storage ubus call")
                pcall(clear_sms_storage.clear, state.modem)
                state.conn:reply(req, { })
            end, {}
        },

        sim_slot_off = {
            function (req, msg)
                local chunk, err, errcode = U.write(state.modem.fds, "AT+CFUN=0" .. "\r\n")
                if_debug("sim_slot", "AT+CFUN=0 resut: " .. tostring(chunk))

                os.execute("ubus call network.interface.modem down")

                state:update("reg", "7", "", "")
                state:update("signal", "", "", "")
                state:update("provider_name", "", "", "")
                state:update("netmode", "", "", "")
                state:update("cpin", "", "", "")
                state:update("balance", "", "", "")


                state.conn:reply(req, { })
            end, {}
        },

        sim_slot_on = {
            function (req, msg)
                local chunk, err, errcode = U.write(state.modem.fds, "AT+CFUN=1" .. "\r\n")
                if_debug("sim_slot", "AT+CFUN=1 resut: " .. tostring(chunk))

                os.execute("ubus call network.interface.modem up")

                state.conn:reply(req, { })
            end, {}
        },

    }
}

function state:make_ubus()
    state.conn = ubus.connect()
    if not state.conn then
        error("tsmodem: Failed to connect to ubus")
    end

    function makeResponse(name)
        local resp = {
            value = state[name] and tostring(state[name].value),
            command = state[name] and tostring(state[name].command),
            changed = state[name] and tostring(state[name].changed),
            updated = state[name] and tostring(state[name].updated),
            comment = state[name] and tostring(state[name].comment)
        }
        return resp
    end

    state.conn:add( ubus_methods )
    state.ubus_methods = ubus_methods
end

function state:update(param, value, command, comment)
    if(value == "" and command == "") then

        local item = {
            ["value"] = "",
            ["command"] = "",
            ["updated"] = "",
            ["changed"] = "",
            ["comment"] = ""
        }

        state[param] = util.clone(item)

    else
        local newval = tostring(value)
        local newcomm = tostring(command)

        local oldval = state:get(param, "value")
        local oldcomm = state:get(param, "command")

        -- время обновления всегда текущее
        -- время изменения - только если изменилось значение или команда
        local upd = tostring(os.time())
        local chd = ""

        if ((oldval ~= newval) or (oldcomm ~= newcomm)) then
            chd = tostring(os.time())
        else
            chd = state:get(param, "changed")
        end

        local item = {
            ["value"] = newval,
            ["command"] = command,
            ["updated"] = upd,
            ["changed"] = chd,
            ["comment"] = comment
        }

        state[param] = util.clone(item)
    end
end

-- returns triplet: noerror, errmsg, value
function state:get(var, param)
    return state[var] and state[var][param] or "Get state error"
end


return state