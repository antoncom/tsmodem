local util = require "luci.util"
local uloop = require "uloop"
local uci = require "luci.model.uci".cursor()

--[[
	Этот подмодуль отвечает за разбор, т.е. парсиниг AT ответов от модема согласно 
	SIM7500_SIM7600 Series_AT Command Manual V3.00 2021.5.18, Chapter 4. AT Commands for Network
]]

local CNSMOD_parser = require 'tsmodem.parser.cnsmod'
local CNSMODES = require 'tsmodem.constants.cnsmodes'
local CUSD_parser = require 'tsmodem.parser.cusd'
local balance_msg_ucs2 = require 'tsmodem.parser.balance_msg_ucs2'
local balance_msg_text = require 'tsmodem.parser.balance_msg_text'
local BAL_parser = require 'tsmodem.parser.balance'
--local balance_event_keys = require "tsmodem.constants.balance_event_keys"
local provider_name = require 'tsmodem.parser.provider_name'

--local ucs2_ascii = require 'tsmodem.parser.ucs2_ascii'



require "tsmodem.driver.util"

local v300_ch4 = {}

-- [modem] is a link to modem.lua functable
function v300_ch4:parse_AT(modem, chunk)
	if chunk:find("+CUSD:") then
		self:balance_parsing_and_update(modem, chunk)
		--[[ Parse and update 3G/4G mode ]]
	elseif chunk:find("+CNSMOD:") then
		local netmode = CNSMOD_parser:match(chunk) or ""
		if((tonumber(netmode) ~= nil) and tonumber(netmode) <= 16) then
			if(CNSMODES[netmode] ~= nil) then
				modem.state:update("netmode", CNSMODES[netmode]:split("|")[2]:gsub("%s+", "") or "", "AT+CNSMOD?", CNSMODES[netmode])
			else
				modem.state:update("netmode", netmode, "AT+CNSMOD?", CNSMODES["0"])
			end
			if_debug("netmode", "AT", "ANSWER", CNSMODES[netmode]:split("|")[2]:gsub("%s+", ""), "[spec/v300_ch4.lua] parse_AT_response() +NSMOD parsed.")
		end

		-- if (modem.debug and (modem.debug_type == "netmode" or modem.debug_type == "all")) then
		-- 	local cnsmode = CNSMODES[netmode] or " | "
		-- 	print("AT says: ","+NSMOD", tostring(modem.timer.interval.netmode).."ms", cnsmode:split("|")[2]:gsub("%s+", "") or "", "","","","Note: GSM mode")
		-- end
	elseif chunk:find("+NITZ") then
		local pname = provider_name:match(chunk)
		if pname and pname ~= "" then
			modem.state:update("provider_name", pname, "+NITZ", "")
			if_debug("provider", "AT", "ANSWER", pname, "[spec/v300_ch4.lua] parse_AT_response() +NITZ parsed every " .. tostring(modem.timer.interval.provider).."ms.")
		end

	elseif chunk:find("+COPS:") then
		local pcode = chunk:split('\"')
		local pname = ""
		if pcode and pcode[2] then
			uci:foreach(modem.config_gsm, "adapter", function(sec)
				if sec.code == pcode[2] then
					pname = sec.name
					modem.state:update("provider_name", pname, "AT+COPS?", pcode[2])
				end
			end)
		if_debug("provider", "AT", "ANSWER", pname, "[spec/v300_ch4.lua] parse_AT_response() +COPS parsed every " .. tostring(modem.timer.interval.provider).."ms.")
		end
	end
end

function v300_ch4:balance_parsing_and_update(modem, chunk)
	if_debug("balance", "AT", "ANSWER", chunk:gsub("%c+", " "), "[spec/v300_ch4.lua]: Balance..")

	local ok, err, sim_id = modem.state:get("sim", "value")
    local balance = 0
	if ok then
		local provider_id = get_provider_id(sim_id)
		local ussd_command = uci:get(modem.config_gsm, provider_id, "balance_ussd")

		-- Если USSD-ответ о балансе поступил в кодировке UCS2 - раскодируем
		local ussd_response_body = balance_msg_ucs2():match(chunk) or balance_msg_text():match(chunk) or "USSD balance response format unknown!"

		if_debug("balance", "AT", "ANSWER", ussd_response_body, "[spec/v300_ch4.lua]: ussd_response_body " .. chunk)

		-- Если USSD-ответ о балансе поступил в виде текста - удаляем одинарные кавычки и переводы строки
		local balance_message = ussd_response_body:gsub("'", "\'"):gsub("\n", " "):gsub("%c+", " ")

		local balance = BAL_parser(sim_id):match(balance_message)
		if_debug("balance", "AT", "ANSWER", balance, "[spec/v300_ch4.lua]: balance value parsed")


------------------------------------------------------------------------------
-- TODO Решить проблему с USSD session (cancel) и ошибочным форматом сообщений
------------------------------------------------------------------------------

		if (balance and type(balance) == "number") then --[[ if balance value is OK ]]
			modem.state:update("balance", balance, ussd_command, balance_message)
			uci:set(modem.config_gsm, provider_id, "balance_last_message", balance_message)
			uci:commit(modem.config_gsm)
			if_debug("balance", "AT", "ANSWER", balance, "[spec/v300_ch4.lua]: Got balance OK.")
		else
			if(#balance_message > 0) then -- If balance message template is wrong
				modem.state:update("balance", "", ussd_command, balance_message)
				if_debug("balance", "AT", "ANSWER", balance_message, "[spec/v300_ch4.lua]: balance_message when parsed can't fetch value.")
			elseif(chunk:find("+CUSD: 2") and #chunk <= 12) then -- we need send USSD once again
				modem.state:update("balance", "", ussd_command, balance_message)
				if_debug("balance", "AT", "ANSWER", chunk, "[spec/v300_ch4.lua]: chunk when balance_message is empty.")
				return ""
			end
		end
	else
		util.perror('driver.lua : ' .. err)
	end
    return balance
end

return v300_ch4