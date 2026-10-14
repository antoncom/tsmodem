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
    csq_creg = 60000,   -- Level and CREG status once pert 60 sec
    slotinfo = 2000,   -- Check tsmslot service by ubus
    check_sim_changed_in_the_same_slot = 1000,
    sim_rescan = 20000   -- как часто искать карту в пустом слоте
}


timer.timeout = {}

timer.interval.sim_probe = 500
timer.timeout.sim_probe  = 1500   -- после инициализации карта отвечает за 500-640 мс



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

local function can_send()
    local m = timer.modem
    if m.sim_probe_waiting and os.time() - (m.sim_probe_time or 0) > 20 then
        m.sim_probe_waiting = false           -- страховка от зависшего флага
    end

    return m.lock.is_automation() and not m.slot_changed_recently
       and not m.sim_probe_waiting and m:is_connected(m.fds)
       and os.time() >= (m.sim_rescan_until or 0)
end
timer.can_send = can_send

function t_SIM_PROBE()
    local m = timer.modem
    local absent = timer.state:get("cpin", "value") == "false"
    local due = (not absent) or (os.time() - (m.sim_probe_time or 0) >= 5)

    if can_send() and due and os.time() >= (m.sim_probe_hold_until or 0) then
        m.sim_probe_waiting = true
        m.sim_probe_time = os.time()
        m.sim_probe_echoed = false
        m.sim_probe_echo_buf = ""
        U.write(m.fds, "AT+CRSM=242,28423,0,0,0\r\n")
        timer.SIM_PROBE_TIMEOUT:set(timer.timeout.sim_probe)
    end
    timer.SIM_PROBE:set(timer.interval.sim_probe)
end
timer.SIM_PROBE = uloop.timer(t_SIM_PROBE)

-- Модем молчит: карты нет. Флаг ожидания НЕ снимаем: порт занят ~12 с.
timer.SIM_PROBE_TIMEOUT = uloop.timer(function()
    local m = timer.modem
    if not m.sim_probe_waiting then return end -- ответ уже пришёл
    if os.time() < (m.sim_probe_hold_until or 0) then return end   -- идёт сброс модема, молчание ожидаемо
    if not m.sim_probe_echoed then
        m.sim_probe_lost = (m.sim_probe_lost or 0) + 1
        if_debug("", "SIM PROBE: command lost (no echo), retry #" .. m.sim_probe_lost, "yellow")
        m.sim_probe_waiting = false        -- модем команду не получил, ждать нечего
        if m.sim_probe_lost >= 5 then
            if_debug("", "SIM PROBE: AT port does not respond", "red")
            timer.state:update("cpin", "", "AT+CRSM=242,28423,0,0,0", "AT port does not respond")
        end
        return
    end

    if_debug("", "SIM PROBE: no answer in " .. timer.timeout.sim_probe .. " ms, cpin=false", "red")
    timer.state:update("cpin", "false", "AT+CRSM=242,28423,0,0,0", "no answer")
end)


-- [[ AT+CREG requests interval ]]
function t_CSQ_CREG()
    local cmds = { "AT+CSQ", "AT+CREG?", "AT+CNSMOD?" }
    local i = 0
    local t
    t = uloop.timer(function()
        if not cmds[i + 1] or not timer.modem:is_connected(timer.modem.fds) then
            return                                  -- список закончился: таймер не перезапускаем
        end
        if can_send() then
            i = i + 1
            U.write(timer.modem.fds, cmds[i] .. "\r\n")
            if_debug("", "ASK " .. cmds[i] .. " every " .. tostring(timer.interval.csq_creg), "yellow")
        end
        t:set(300)                                  -- следующая команда или повтор, если порт был занят
    end)
    t:set(300)
    if not timer.modem.iccid and timer.state:get("cpin", "value") == "true" then
        timer.request_iccid()
    end
    timer.CSQ_CREG:set(timer.interval.csq_creg)
end
timer.CSQ_CREG = uloop.timer(t_CSQ_CREG)

function t_SIM_RESCAN()
    local m = timer.modem
    if timer.state:get("cpin", "value") == "false" and can_send() then
        if_debug("", "SIM RESCAN: AT+CFUN=0/1 to look for a card", "yellow")
        m.sim_probe_hold_until = os.time() + 8      -- на время сброса проверки не слать
        m.sim_rescan_until = os.time() + 6
        --U.write(m.fds, "AT+CFUN=0\r\n")
        timer.state:sim_off()
        timer.state:update("cpin", "false", "AT+CFUN=0", "sim rescan")
        timer.SIM_RESCAN_ON:set(2000)
    end
    timer.SIM_RESCAN:set(timer.interval.sim_rescan)
end
timer.SIM_RESCAN = uloop.timer(t_SIM_RESCAN)

-- Вторая половина сброса: включить радиочасть обратно
timer.SIM_RESCAN_ON = uloop.timer(function()
    local m = timer.modem
    if m:is_connected(m.fds) then
        --U.write(m.fds, "AT+CFUN=1\r\n")
        timer.state:sim_on()
    end
end)

function timer.request_iccid()
    local tries = 0
    local t
    t = uloop.timer(function()
        tries = tries + 1
        if can_send() then
            U.write(timer.modem.fds, "AT+CRSM=176,12258,0,0,10\r\n")
        elseif tries < 150 then
            t:set(300)                     -- порт занят, попробуем позже
        end
    end)
    t:set(700)
end


function t_SLOT()
    local tsmslot_info = timer.state.conn:call("tsmslot", "info", {})
    local last_switch_time = tsmslot_info and tsmslot_info["last_switch_time"] or 0
    local last_reset_time = tsmslot_info and tsmslot_info["last_reset_time"] or 0

    if(tonumber(last_switch_time) and (os.time() - tonumber(last_switch_time)) < 30) then
        -- Слот только что переключили: забываем провайдера предыдущей Сим-карты.
        -- Иначе, пока +COPS/+NITZ игнорируются, ubus "provider_name" отдаёт старого провайдера,
        -- и applogic (14_rule) пропишет в интерфейс "modem" чужой APN.
        if not timer.modem.slot_changed_recently then
            timer.state:update("provider_name", "", "", "")
        end
        timer.modem.slot_changed_recently = true
        if_debug(timer.modem.debug_type, "SLOT check every " .. tostring(tonumber(timer.interval.slotinfo)/1000) .. "s: changed recently [" .. tostring(timer.modem.slot_changed_recently) .. "]", "yellow")
        if_debug(timer.modem.debug_type, "----------------------", "yellow")

    else
        -- Окно после переключения закончилось. Карта к этому времени обычно уже зарегистрировалась,
        -- но +CREG/AT+COPS? внутри окна не обрабатывались. Опрашиваем модем сразу, не дожидаясь
        -- следующего цикла CSQ_CREG (раз в 60 сек): ответ +CREG: 1/5 запустит AT+COPS?,
        -- и провайдер определится через пару секунд, а не через 30..90 сек после переключения.
        if timer.modem.slot_changed_recently then
            timer.CSQ_CREG:set(100)
        end
        timer.modem.slot_changed_recently = false
    end

    if(tonumber(last_reset_time) and (os.time() - tonumber(last_reset_time)) < 45) then
        timer.modem.slot_reset_recently = true
    else
        timer.modem.slot_reset_recently = false
    end

    timer.SLOT:set(timer.interval.slotinfo)
end
timer.SLOT = uloop.timer(t_SLOT)

return timer
