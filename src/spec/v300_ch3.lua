local util = require "luci.util"
local uloop = require "uloop"
local uci = require "luci.model.uci".cursor()

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

--[[
	Этот подмодуль отвечает за разбор - парсиниг AT ответов от модема согласно 
	A76XXSeries_AT CommandManual V1.06 2021.11.9, а также:
	SIM7500_SIM7600 Series_AT Command Manual V3.00 2021.5.18, Chapter 3. AT Commands According to V.25TER

]]

local CPIN_parser = require 'tsmodem.parser.cpin'
local CREG_parser = require 'tsmodem.parser.creg'
local CSQ_parser = require 'tsmodem.parser.csq'

local notifier = require "tsmodem.driver.notifier"
local clear_sms_storage = require "tsmodem.util.clear_sms_storage"

require "tsmodem.driver.util"

local v300_ch3 = {}

-- [modem] is a link to modem.lua functable
function v300_ch3:parse_AT(modem, chunk)
	if (chunk:find("+CME ERROR") or chunk:find("+CPIN:") or chunk:find("+SIMCARD: NOT AVAILABLE")) then
		local cpin = CPIN_parser:match(chunk)
		if_debug("cpin", "AT ANSWER CPIN" .. tostring(cpin) .. " when chunk is: " .. chunk:gsub("%c+", " "))
		if_debug("cpin", "----------------------")

		local SWITCHING = modem.state:get("switching", "value")

		if cpin and (SWITCHING ~= "true") and (cpin == "true" or cpin == "false" or cpin == "failure") then
	        if cpin == "true" then
	            modem.sim_probe_hold_until = os.time() + 5   -- дать карте проинициализироваться
	            modem.timer.request_iccid()
	        end

			if cpin == "true" then
	            modem.sim_probe_hold_until = os.time() + 5   -- дать карте проинициализироваться
	            modem.timer.request_iccid()
	        elseif chunk:find("SIM REMOVED", 1, true) then
	            os.execute("ubus call network.interface.modem down &")   -- карты нет: дозвон бессмыслен
	        end

	        modem.state:update("cpin", cpin, "AT+CPIN?", "")
	        return
	    end

	elseif chunk:find("+CREG:") then
		local creg = CREG_parser:match(chunk)
		if_debug("reg", "AT ANSWER +CREG: " .. tostring(creg) .. " when chunk is: " .. chunk:gsub("%c+", " "))
		if_debug("reg", "----------------------")
		if creg and creg ~= "" then
			modem.state:update("reg", creg, "AT+CREG?", "")
			modem.state:update("usb", "connected", modem.device .. " open", "")

			if creg == "1" or creg == "5" then
			    local tries = 0
			    local t
			    t = uloop.timer(function()
			        tries = tries + 1
			        if modem.timer.can_send() then
			            U.write(modem.fds, "AT+COPS?\r\n")
			        elseif tries < 10 then
			            t:set(300)                 -- порт занят, попробуем чуть позже
			        end
			    end)
			    t:set(1500)
			end
		end

	elseif chunk:find("+CSQ:") then
		local signal = CSQ_parser:match(chunk)
		if_debug("signal", "AT ANSWER +CSQ: " .. tostring(signal) .. " when chunk is: " .. chunk:gsub("%c+", " "))
		if_debug("signal", "----------------------")

		--local no_signal_aliase = {"0", "99", "31", "nil", nil, ""}
		local no_signal_aliase = {"99", "nil", nil, ""}
		if not util.contains(no_signal_aliase, signal) then
			signal = tonumber(signal) or false
			if (signal and signal >= 0 and signal <= 31) then signal = math.ceil(signal * 100 / 31) else signal = "" end
		else
			signal = ""
		end
		modem.state:update("signal", tostring(signal), "AT+CSQ", "")
	end
end

return v300_ch3