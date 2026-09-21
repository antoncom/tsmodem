-- Модуль таймеров служит для запуска различных таймеров и задержек.
-- Используется для периодического опроса GSM-модема, т.е. отправки АТ-команд модему с заданным интервалом.
-- Например, АТ-CSQ (запрос уровня сигнала), посылаемый в GSM-модем через каждые 4 секунды.
-- Данный модуль свяан с другими модулями сервиса - см. .init()

local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"
local nixio = require "nixio"


local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'


require "tsmodem.driver.util"

local timer = {}
timer.modem = nil
timer.state = nil
timer.notifier = nil

timer.interval = {
    general = 1400,     -- use 3000 interval in debug mode
    reg = 4000,         -- Sim registration state (checking interval)
    cpin = 5000,        -- Sim inserted or not?
    signal = 6000,      -- Signal strength (checking interval)
    balance = 1800,    -- Balance value (checking interval) - 60 sec. minimum to avoid Provider blocking USSD
    netmode = 7000,     -- 4G/3G mode state (checking interval)
    provider = 8000,    -- GSM provider name (autodetection checking interval)
    slotinfo = 10000,   -- Check tsmslot service by ubus

    last_balance_request_time = os.time(),  -- Helper. Need to avoid doing USSD requests too often.
    balance_repeated_request_delay = 125,   -- If GSM opeator doen't send back the balance USSD-response
                                            -- then we should wait 1..2 mins before repeating
}

timer.timeout = {
    balance = 60000      -- Once a balance USSD requested, "in progress" state is set on "tsmodem.driver balance" method.
}                       -- Then, if by some reason provider will not respond to the balance USSD request,
                        -- then we clear balance state after the timeout.


timer.init = function(modem, state, notifier)
    timer.modem = modem
    timer.state = state
    timer.notifier = notifier
    return timer
end

-- Периодически запускает инициализацию модуля modem, а также запуск опроса
-- Это нужно для проверки того, что модем подключен, идентифицирован на логическом порту.
-- В случае "падения", происходит инициализация и запуска процесса опроса.
function t_general()
    timer.modem:init()
    timer.modem:poll()
    timer.general:set(timer.interval.general)
end
timer.general = uloop.timer(t_general)

-- [[ AT+CREG requests interval ]]
function t_CREG()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("reg", "AT ASK AT+CREG? every " .. tostring(timer.interval.reg))
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CREG?" .. "\r\n")
            end
        end
    end
    timer.CREG:set(timer.interval.reg)
end
timer.CREG = uloop.timer(t_CREG)

-- [[ AT+CPIN? requests interval ]]
function t_CPIN()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("cpin", "AT ASK AT+CPIN? every " .. tostring(timer.interval.cpin).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CPIN?" .. "\r\n")
            end
        end
    end
    timer.CPIN:set(timer.interval.cpin)
end
timer.CPIN = uloop.timer(t_CPIN)

-- [[ AT+CSQ requests interval ]]
function t_CSQ()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("signal", "AT ASK AT+CSQ every " .. tostring(timer.interval.signal).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CSQ" .. "\r\n")
            end
        end
    end
    timer.CSQ:set(timer.interval.signal)
end
timer.CSQ = uloop.timer(t_CSQ)

-- [[ AT+COPS: get GSM provider name from the GSM network ]]
function t_COPS()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("provider_name", "AT ASK AT+COPS? every " .. tostring(timer.interval.provider).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+COPS?" .. "\r\n")
            end
        else
            timer.state:update("provider_name", "", "", "")
            if_debug("", "It's too early after switch to send AT", "yellow")
        end
    end
    timer.COPS:set(timer.interval.provider)
end
timer.COPS = uloop.timer(t_COPS)


--[[ Get 3G/4G mode from the GSM network ]]
function t_CNSMOD()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                local reg = timer.state:get("reg", "value")
                if reg == "1" then
                    if_debug("netmode", "AT ASK AT+CNSMOD? every " .. tostring(timer.interval.netmode).."ms")
                    local chunk, err, errcode = U.write(timer.modem.fds, "AT+CNSMOD?" .. "\r\n")
                end
            end
        end
    end
    timer.CNSMOD:set(timer.interval.netmode)
end
timer.CNSMOD = uloop.timer(t_CNSMOD)


--[[ Balance request timeout ]]
function t_BAL_TIMEOUT()
    local val = timer.state:get("balance", "value")
    if val == "*" then
        timer.state:update("balance", "", "", "")
        if (timer.modem.debug and (timer.modem.debug_type == "balance" or timer.modem.debug_type == "all")) then
            if_debug("", string.format("[timer.lua]: Clear balance on BAL_TIMEOUT: %s %s %s", tostring(noerror), tostring(errmsg), tostring(val)))
        end
    end
end
timer.BAL_TIMEOUT = uloop.timer(t_BAL_TIMEOUT)

--[[ Balance request timeout ]]
function t_SLOT()
    pcall(function()
        local conn = ubus.connect()
        local tsmslot_info = timer.state.conn:call("tsmslot", "info", {})
        local last_switch_time = tsmslot_info and tsmslot_info["last_switch_time"] or 0
        if(tonumber(last_switch_time) and (os.time() - tonumber(last_switch_time)) < 30) then
            timer.modem.slot_changed_recently = true
            if_debug("", "SLOT check every " .. tostring(tonumber(timer.interval.slotinfo)/1000) .. "s: changed recently [" .. tostring(timer.modem.slot_changed_recently) .. "]", "yellow")
            if_debug("", "----------------------", "yellow")

        else
            timer.modem.slot_changed_recently = false
            if_debug("", "SLOT check every " .. tostring(tonumber(timer.interval.slotinfo)/1000) .. "s: changed recently [" .. tostring(timer.modem.slot_changed_recently) .. "]", "white")
            if_debug("", "----------------------", "white")
        end
    end)
    timer.SLOT:set(timer.interval.slotinfo)
end
timer.SLOT = uloop.timer(t_SLOT)



--[[---------------------- FOR TESTING ----------]]


-- [[ AT+CGREG? PS-регистрация (GPRS) PPP работает через PS, а не CS ]]
function t_CGREG()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("signal", "AT ASK AT+CGREG? every " .. tostring(timer.interval.signal).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CGREG?" .. "\r\n")
            end
        end
    end
    timer.CGREG:set(timer.interval.signal)
end
timer.CGREG = uloop.timer(t_CGREG)

-- [[ AT+CEREG? EPS-регистрация (LTE) Для LTE data нужна именно EPS-регистрация ]]
function t_CEREG()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("signal", "AT ASK AT+CEREG? every " .. tostring(timer.interval.signal).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CEREG?" .. "\r\n")
            end
        end
    end
    timer.CEREG:set(timer.interval.signal)
end
timer.CEREG = uloop.timer(t_CEREG)

-- [[ AT+CGATT? Attach к PS Без attach PPP не поднимется ]]
function t_CGATT()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("signal", "AT ASK AT+CGATT? every " .. tostring(timer.interval.signal).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CGATT?" .. "\r\n")
            end
        end
    end
    timer.CGATT:set(timer.interval.signal)
end
timer.CGATT = uloop.timer(t_CGATT)


-- [[ AT+CGACT? Активные PDP-контексты Нужен активный контекст для PPP ]]
function t_CGACT()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("signal", "AT ASK AT+CGACT? every " .. tostring(timer.interval.signal).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CGACT?" .. "\r\n")
            end
        end
    end
    timer.CGACT:set(timer.interval.signal)
end
timer.CGACT = uloop.timer(t_CGACT)

-- [[ AT+CGDCONT? Настройки APN Напр. APN для Beeline ]]
function t_CGDCONT()
    if timer.modem.lock.is_automation() then
        local SWITCHING = timer.modem.slot_changed_recently
        if not SWITCHING then
            if(timer.modem:is_connected(timer.modem.fds)) then
                if_debug("signal", "AT ASK AT+CGDCONT? every " .. tostring(timer.interval.signal).."ms")
                local chunk, err, errcode = U.write(timer.modem.fds, "AT+CGDCONT?" .. "\r\n")
            end
        end
    end
    timer.CGDCONT:set(timer.interval.signal)
end
timer.CGDCONT = uloop.timer(t_CGDCONT)

return timer
