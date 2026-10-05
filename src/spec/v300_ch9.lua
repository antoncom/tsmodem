local util = require "luci.util"
local uloop = require "uloop"
local uci = require "luci.model.uci".cursor()

--[[
	Этот подмодуль отвечает за разбор, т.е. парсиниг AT ответов от модема согласно 
	A76XXSeries_AT CommandManual V1.06 2021.11.9, а также:
	SIM7500_SIM7600 Series_AT Command Manual V3.00 2021.5.18, Chapter 9. AT Commands for SMS
]]

local U = require 'posix.unistd'

local cmgs_ok = require 'tsmodem.parser.cmgs_ok'
local cmgs_error = require 'tsmodem.parser.cmgs_error'
local remote_control_pars = require 'tsmodem.parser.parser_sms'
local pdu_decoder = require 'tsmodem.util.pdu_decoder'
local cmgr_pdu = require 'tsmodem.parser.cmgr_pdu'

require "tsmodem.driver.util"

local v300_ch9 = {}
v300_ch9.modem = nil
v300_ch9.resive_sms_counter = nil
v300_ch9.read_sms_timer = nil

-- [modem] is a link to modem.lua functable
function v300_ch9:parse_AT(modem, chunk)
	self.modem = modem
	if chunk:find("+CMTI:") then
		modem.sim_probe_hold_until = os.time() + 6		-- не мешать чтению SMS
		
		self.resive_sms_counter = remote_control_pars:get_sms_count(chunk)
		if_debug("send_at", "AT ANSWER +CMTI SMS Counter: " .. tostring(self.resive_sms_counter) .. " when chunk is: " .. chunk:gsub("%c+", " "))
		if_debug("send_at", "----------------------")

		-- Задержка для модема, дающая время на обработку запроса
		self.read_sms_timer = uloop.timer(v300_ch9:AtCommandReadSMS())
		self.read_sms_timer:set(3000) -- Задержка 3 сек

	-- Обработать ответ и выделить тело смс.
	elseif chunk:find("+CMGR:") then
		local pos = chunk:find("+CMGR:", 1, true)
		chunk = chunk:sub(pos)		-- отбросить всё, что пришло перед ответом
		
		if_debug("send_at", "AT ANSWER +CMGR "  .. " when chunk is: " .. chunk:gsub("%c+", " "))
		if_debug("send_at", "----------------------")

		local pdu_data = cmgr_pdu:match(chunk)
		if pdu_data == nil then
			if_debug("send_at", "PDU DATA: nil")
			if_debug("send_at", "----------------------")
		else
			if_debug("send_at", "AT ANSWER +CMGR pdu_data: " .. tostring(pdu_data))
			if_debug("send_at", "----------------------")

			local parsed_sms = pdu_decoder.parse(pdu_data)


			local event_name = ""
			if self.modem.lock.owner == "tsmsms" then
				event_name = v300_ch9.modem.defined_events[5]
				if_debug("send_at", "EVENT NAME: " .. tostring(event_name), "red")
			elseif self.modem.lock.owner == "" then
				event_name = v300_ch9.modem.defined_events[4]
				if_debug("send_at", "EVENT NAME: " .. tostring(event_name), "blue")
			end

			local event_payload = {
				answer = chunk,
				["sms_phone"] = parsed_sms.sender_number,
				["sms_command"] = parsed_sms.message_text,
			}
			v300_ch9.modem.notifier:fire(event_name, event_payload)
		end

	elseif (chunk:find("AT%+CMGS=") or chunk:find("%+CMGS: ") or chunk:find("%+CMS ERROR")) then
		local removed_ctrlZ_chunk = chunk:gsub("%c", " ")
		local is_sms_sent_ok = cmgs_ok:match(removed_ctrlZ_chunk) and type(cmgs_ok:match(removed_ctrlZ_chunk) == "string")
		local is_sms_sent_error = cmgs_error:match(removed_ctrlZ_chunk) and type(cmgs_error:match(removed_ctrlZ_chunk) == "string")

		if_debug("send_at", "AT ANSWER +CMGS: Removed ctrlZ: " .. tostring(removed_ctrlZ_chunk) .. " sent_OK: [" .. tostring(is_sms_sent_ok) .. "]. Sent_Err: [" .. tostring(is_sms_sent_error) .. "]")
		if_debug("send_at", "----------------------")


		local event_name = ""
		local event_payload = {}

		local automation_mode = ""
		if v300_ch9.modem.lock.is_automation() then automation_mode = "run" else automation_mode = "stop" end
		if is_sms_sent_ok then
			event_name = v300_ch9.modem.defined_events[2]
			event_payload = {
				answer = cmgs_ok:match(removed_ctrlZ_chunk),
				automation = automation_mode
			}
			v300_ch9.modem.notifier:fire(event_name, event_payload)

		elseif is_sms_sent_error then
			event_name = v300_ch9.modem.defined_events[3]
			event_payload = {
				answer = cmgs_error:match(removed_ctrlZ_chunk),
				automation = automation_mode
			}
			v300_ch9.modem.notifier:fire(event_name, event_payload)
		else
			-- TODO: it seems not used anywhere.

			-- event_name = v300_ch9.modem.defined_events[1]
			-- event_payload = {
			-- 	answer = removed_ctrlZ_chunk,
			-- 	automation = automation_mode
			-- }
		end
	elseif chunk:match("+CMGS:") then
		--modem.state.conn:notify(modem.state.ubus_methods["tsmodem.driver"].__ubusobj, "SMS-SENT", {answer = chunk} )
	end
end

-- Обработчик для чтения СМС
function v300_ch9:AtCommandReadSMS()
	return function()
		-- Запрос в модем на считывание принятой смс
		local at_set_PDU_mode = "\r\nAT+CMGF=0\r\n"
		U.write(v300_ch9.modem.fds, at_set_PDU_mode)
		local at_get_sms_counter = "\r\nAT+CMGR=" .. tostring(v300_ch9.resive_sms_counter) .. "\r\n"
		U.write(v300_ch9.modem.fds, at_get_sms_counter)
		if_debug("send_at", "AT ANSWER +CMGR: Get SMS counter: " .. tostring(at_get_sms_counter))
		if_debug("send_at", "----------------------")

		v300_ch9.read_sms_timer:cancel() -- отмена таймера
	end
end


function v300_ch9:parse_balance_and_update(modem, sms)
	if
		sms["sender"] == "000100" or -- Megafon
		sms["sender"] == "111" or -- MTC
		sms["sender"] == "105" -- Tele2
	then
		local balance_str = string.match(sms["text"], "[%+%-]?%d+%.?%d*")
		if balance_str ~= nil then
			modem.state:update("balance", balance_str, "", "")
		end
	end
end

return v300_ch9