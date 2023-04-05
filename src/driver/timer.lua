local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmodem.driver.util"

local timer = {}
timer.modem = nil
timer.state = nil
timer.stm = nil

timer.interval = {
    general = 3000,
    reg = 3000,         -- Sim registration state (checking interval)
    signal = 4000,      -- Signal strength (checking interval)
    balance = 18000,   -- Balance value (checking interval) - 60 sec. minimum to avoid Provider blocking USSD
    netmode = 5000,     -- 4G/3G mode state (checking interval)
    provider = 6000,    -- GSM provider name (autodetection checking interval)
    ping = 4000,        -- Ping GSM network (checking interval)

    last_balance_request_time = os.time(),  -- Helper. Need to avoid doing USSD requests too often.

    balance_repeated_request_delay = 125    -- If GSM opeator doen't send back the balance USSD-response
                                            -- then we should wait 1..2 mins before repeating
}

--[[ Step-by-step delays of switching Sim-card process ]]
timer.switch_delay = {
    ["1_MDM_UNPOLL"] = 100,     -- Stop modem polling since ubus call tsmodem.driver do_switch runs
    ["2_STM_SIM_SEL"] = 200,    -- Select Sim-card by STM32 since modem unpolled
    ["3_STM_SIM_RST_0"] = 900,  -- Send RST=0 by STM32 since sim card selected by STM32
    ["4_STM_SIM_RST_1"] = 900,  -- Send RST=1 by STM32 since STM32 RST 0 send
    ["5_MDM_REPEAT_POLL"] = 100,-- Start modem polling since STM32 RST 1 send
    --["6_MDM_END_SWITCHING"] = 2000,


}


timer.init = function(modem, state, stm)
    timer.modem = modem
    timer.state = state
    timer.stm = stm
    return timer
end

--[[ General driver timer ]]
function t_general()
    timer.modem:init()
    timer.modem:poll()
    timer.modem:check_session_and_set_automation_mode()

    timer.general:set(timer.interval.general)
end
timer.general = uloop.timer(t_general)


-- [[ AT+CREG requests interval ]]
function t_CREG()
    if timer.modem.automation == "run" then
        local SWITCHING = (timer.state:get("switching", "value") == "true")
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if (timer.modem.debug and timer.modem.debug_type == "reg") then print("AT sends: ","AT+CREG") end
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CREG?" .. "\r\n")
            end
            timer.CREG:set(timer.interval.reg)
        end
    else
        timer.CREG:set(timer.interval.reg)
    end
end
timer.CREG = uloop.timer(t_CREG)

-- [[ AT+CSQ requests interval ]]
function t_CSQ()
    if timer.modem.automation == "run" then
        local SWITCHING = (timer.state:get("switching", "value") == "true")
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if (timer.modem.debug and timer.modem.debug_type == "signal") then print("AT sends: ","AT+CSQ") end
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CSQ" .. "\r\n")
            end
            timer.CSQ:set(timer.interval.signal)
        end
    else
        timer.CSQ:set(timer.interval.signal)
    end
end
timer.CSQ = uloop.timer(t_CSQ)

-- [[ AT+CUSD requests interval ]]
function t_CUSD()
    if timer.modem.automation == "run" then
        local SWITCHING = (timer.state:get("switching", "value") == "true")
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                --[[ Get balance only if SIM is registered in the GSM network ]]

                local ok, err, reg = timer.state:get("reg", "value")
                if ok and reg == "1" then
                    local ok, err, sim_id = timer.state:get("sim", "value")
                    if ok then
                        if(sim_id == "0" or sim_id =="1") then
                            local ok, err, last_balance_time = timer.state:get("balance", "time")
                            if (tonumber(last_balance_time) and (last_balance_time ~= "0")) then
                                local timecount = os.time() - tonumber(last_balance_time)
                                if( timecount >= timer.interval.balance/1000 ) then
                                    --[[ Avoid noise in USSD requests ]]
                                    if (os.time() - timer.interval.last_balance_request_time) > timer.interval.balance_repeated_request_delay then
                                        local provider_id = get_provider_id(sim_id)

                                        local ussd_command = string.format("AT+CUSD=2,%s,15\r\n", uci:get(timer.modem.config_gsm, provider_id, "balance_ussd"))
                                        if (timer.modem.debug and timer.modem.debug_type == "balance") then print("----->>> Cancel USSD session before start new one: "..ussd_command) end
                                        local chunk, err, errcode = U.write(timer.modem.fds, ussd_command)

                                        local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(timer.modem.config_gsm, provider_id, "balance_ussd"))
                                        if (timer.modem.debug and timer.modem.debug_type == "balance") then print("----------------------->>> Sending BALANCE REQUEST one time per "..tostring(timer.interval.balance/1000).."sec") end

                                        local chunk, err, errcode = U.write(timer.modem.fds, ussd_command)

                                        timer.interval.last_balance_request_time = os.time()
                                    end
                                end
                            end
                            timer.CUSD:set(1000)
                        end
                    else
                        util.perror("ERROR: sim or value not found in state.")
                    end
                else
                    timer.CUSD:set(1000)
                end
            else
                timer.CUSD:set(1000)
            end
        end
    else
        timer.CUSD:set(1000)
    end
end
timer.CUSD = uloop.timer(t_CUSD)


-- [[ AT+COPS: get GSM provider name from the GSM network ]]
function t_COPS()
    if timer.modem.automation == "run" then
        local SWITCHING = (timer.state:get("switching", "value") == "true")
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if (timer.modem.debug and timer.modem.debug_type == "provider") then print("AT sends: ","AT+COPS?") end
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+COPS?" .. "\r\n")
            end
            timer.COPS:set(timer.interval.provider)
        end
    else
        timer.COPS:set(timer.interval.provider)
    end
end
timer.COPS = uloop.timer(t_COPS)


-- [[ PING Google to check internet connection ]]
function t_PING()
    function p1(r) --[[ call back is empty as not needed now. ]]   end
    if timer.modem.automation == "run" then
        local ok, err, reg = timer.modem.state:get("reg", "value")
        if(reg =="1") then
            local SWITCHING = (timer.state:get("switching", "value") == "true")
            if not SWITCHING then
                local _,_,sim_id = timer.state:get("sim", "value")
                local host = "8.8.8.8"
                local host_spc_sim = string.format("%s %s", host, sim_id)
                if (timer.modem.debug and timer.modem.debug_type == "ping") then print("PING runs: ","ping.sh", host_spc_sim) end
                uloop.process("/usr/lib/lua/tsmodem/util/ping.sh", {"--host", host_spc_sim }, {"PROCESS=1"}, p1)
                timer.PING:set(timer.interval.ping)
            end
        end
    else
        timer.PING:set(timer.interval.ping)
    end
end
timer.PING = uloop.timer(t_PING)


--[[ Get 3G/4G mode from the GSM network ]]
function t_CNSMOD()
    if timer.modem.automation == "run" then
        local SWITCHING = (timer.state:get("switching", "value") == "true")
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                local _,_,reg = timer.state:get("reg", "value")
                if reg == "1" then
                    if (timer.modem.debug and timer.modem.debug_type == "netmode") then print("AT sends: ","AT+CNSMOD?") end
                    local chunk, err, errcode = U.write(timer.modem.fds, "AT+CNSMOD?" .. "\r\n")
                    --local chunk, err, errcode = U.write(timer.modem.fds, "AT+CNSMOD=1" .. "\r\n")
                end
            end
            timer.CNSMOD:set(timer.interval.netmode)
        end
    else
        timer.CNSMOD:set(timer.interval.netmode)
    end
end
timer.CNSMOD = uloop.timer(t_CNSMOD)


--[[ Switch Sim: Unpoll modem ]]
function t_SWITCH_1()
    if timer.modem.automation == "run" then
        local resp, n = {}, 0
        local res, sim_id = timer.stm:command("~0:SIM.SEL=?")
        if res == "OK" then
            timer.state:update("sim", tostring(sim_id), "~0:SIM.SEL=?")
        else
            print("tsmodem: Error while sending command ~0:SIM.SEL=? to STM32.")
        end

        if timer.modem.fds then
            timer.modem.unpoll()
            U.close(timer.modem.fds)
        end

        timer.SWITCH_2:set(timer.switch_delay["2_STM_SIM_SEL"])
        if (timer.modem.debug) then print("SWITCH_1_MDM_UNPOLL: done.") end
    end
end
timer.SWITCH_1 = uloop.timer(t_SWITCH_1)

--[[ Switch Sim: Select sim card ]]
function t_SWITCH_2()
    local _,_,current_sim = timer.state:get("sim", "value")

    local sim_to_switch = ""
    if(current_sim == "0") then
        sim_to_switch = "1"
    elseif(current_sim == "1") then
        sim_to_switch = "0"
    end

    local res, val = timer.stm:command("~0:SIM.SEL=" .. sim_to_switch)
    if ("OK" == res) then

        timer.state:update("sim", sim_to_switch, "~0:SIM.SEL=" .. sim_to_switch, "")
        timer.state:update("stm32", "OK", "~0:SIM.SEL=" .. sim_to_switch, "")
        timer.state:update("reg", "", "", "")
    	timer.state:update("signal", "", "", "")
    	timer.state:update("balance", "", "", "")
    	timer.state:update("netmode", "", "", "")
    	timer.state:update("provider_name", "", "", "")
    	timer.state:update("ping", "", "", "")
        timer.state.ping.time = "0"

        local provider_id = get_provider_id(sim_to_switch)
        local apn = uci:get(timer.modem.config_gsm, provider_id, "gate_address") or "internet"
        uci:set("network", "tsmodem", "apn", apn)
        uci:save("network")
        uci:commit("network")

        if (timer.modem.debug) then print(string.format("SWITCH_2_STM_SIM_SEL: ~0:SIM.SEL=%s done.", sim_to_switch)) end


        timer.SWITCH_3:set(timer.switch_delay["3_STM_SIM_RST_0"])
    else
        print(string.format("SWITCH_2_STM_SIM_SEL: ~0:SIM.SEL=%s ERROR. (see timer.lua)", sim_to_switch))
    end

end
timer.SWITCH_2 = uloop.timer(t_SWITCH_2)


--[[ Switch Sim: reset modem on ]]
function t_SWITCH_3()

    local res, val = timer.stm:command("~0:SIM.RST=0")

    if "OK" == res then
        timer.state:update("stm32", "OK", "~0:SIM.RST=0", "")
        if (timer.modem.debug) then print("SWITCH_3_STM_SIM_RST_0: ~0:SIM.RST=0 done.") end

        timer.SWITCH_4:set(timer.switch_delay["4_STM_SIM_RST_1"])
    else
        timer.state:update("stm32", "ERROR", "~0:SIM.RST=0", "")
        print("SWITCH_3: ~0:SIM.RST=0 ERROR (see timer.lua)")
    end

end
timer.SWITCH_3 = uloop.timer(t_SWITCH_3)


--[[ Switch Sim: reset modem off ]]
function t_SWITCH_4()

    local res, val = timer.stm:command("~0:SIM.RST=1")

    if "OK" == res then
        timer.state:update("stm32", "OK", "~0:SIM.RST=1", "")
        if (timer.modem.debug) then print("SWITCH_4_STM_SIM_RST_1: ~0:SIM.RST=1 done.") end
        timer.SWITCH_5:set(timer.switch_delay["5_MDM_REPEAT_POLL"])
    else
        timer.state:update("stm32", "ERROR", "~0:SIM.RST=1", "")
        print("SWITCH_4: ~0:SIM.RST=1 ERROR (see timer.lua)")
    end

end
timer.SWITCH_4 = uloop.timer(t_SWITCH_4)


--[[ Switch Sim: delay before repeat modem polling ]]
function t_SWITCH_5()
    timer.modem:init()

    if (timer.modem.debug) then print("SWITCH_5_POLL_ENABLE.") end
end
timer.SWITCH_5 = uloop.timer(t_SWITCH_5)


return timer
