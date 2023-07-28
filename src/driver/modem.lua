
local socket = require "socket"
local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"
local sys  = require "luci.sys"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

-- Constants & utils
local CNSMODES = require 'tsmodem.constants.cnsmodes'
local AT_RELATED_UBUS_METHODS = require 'tsmodem.constants.AT_related_ubus_methods'
require "tsmodem.util.split_string"
require "tsmodem.driver.util"
local checkubus = require "tsmodem.util.checkubus"
local balance_event_keys = require "tsmodem.constants.balance_event_keys"


-- Parsers
local CPIN_parser = require 'tsmodem.parser.cpin' -- not needed anymore
local CREG_parser = require 'tsmodem.parser.creg'
local CSQ_parser = require 'tsmodem.parser.csq'
local CUSD_parser = require 'tsmodem.parser.cusd'
local SMS_parser = require 'tsmodem.parser.sms'
local BAL_parser = require 'tsmodem.parser.balance'
local CNSMOD_parser = require 'tsmodem.parser.cnsmod'
local ucs2_ascii = require 'tsmodem.parser.ucs2_ascii'
local provider_name = require 'tsmodem.parser.provider_name'
local check_host = require 'tsmodem.parser.hostip'

local modem = {}
modem.debug = (uci:get("tsmodem", "debug", "enable") == "1") and true
modem.debug_type = uci:get("tsmodem", "debug", "type")

modem.device = arg[1] or '/dev/ttyUSB1'         -- First port
modem.fds = nil                                 -- File descriptor for /dev/ttyUSB2
modem.fds_ev = nil      						-- Event loop descriptor
modem.ws_fds = nil								-- Websocket file descriptor
modem.ws_fds_ev = nil
modem.ws_pipeout_file = "/tmp/wspipeout.fifo"	-- Gwsocket creates it
modem.ws_pipein_file = "/tmp/wspipein.fifo" -- Gwsocket creates it


modem.automation = "run"						-- "run" or "stop" are only possible
												-- "run" means gather modem state, sending AT-commands automatically (see timer.lua)
												-- "stop" means don't gather the one. It is used when user open SIM-setting panel in the web UI
												-- Also, "stop" is used when user needs to send AT manualy via web-console, or via "send_at" ubus method
-- [[ UCI staff ]]
modem.config = "tsmodem"
modem.config_gsm = "tsmodem_adapter_provider"
modem.section = "sim"


function modem:init()
	if not self:is_connected(modem.fds) then
		modem:unpoll()
		if modem.fds then
			U.close(modem.fds)
			modem.state:update("usb", "disconnected", modem.device .. " close")
			modem.state:update("reg", "7", "AT+CREG?")
			modem.state:update("signal", "", "AT+CSQ")
			modem.state:update("cpin","", "","")
		end

		local fds, err, errnum = F.open(modem.device, bit.bor(F.O_RDWR, F.O_NONBLOCK))
		if fds then
			M.tcsetattr(fds, 0, {
			   cflag = M.B115200 + M.CS8 + M.CLOCAL + M.CREAD,
			   iflag = M.IGNPAR,
			   oflag = M.OPOST,
			   cc = {
			      [M.VTIME] = 0,
			      [M.VMIN] = 1,
			   }
			})
			modem.fds = fds

			local ok, err, sim_id = modem.state:get("sim", "value")
			if ok and (sim_id == "1" or sim_id == "0") then
                local provider_id = get_provider_id(sim_id)
				local apn_provider = uci:get(modem.config_gsm, provider_id, "gate_address") or "APNP"
				local apn_network = uci:get("network", "tsmodem", "apn") or "APNN"
				if(apn_provider ~= apn_network) then
					uci:set("network", "tsmodem", "apn", apn_provider)
					uci:save("network")
					uci:commit("network")
				end
			end

			modem.state:update("usb", "connected", modem.device .. " open", "")
			modem.state:update("reg", "7", "AT+CREG?", "")
			modem.state:update("signal", "", "AT+CSQ", "")
			modem.state:update("switching","false", "","")
			modem.state:update("cpin","", "","")

		end
	end
end


--[[
	Modem driver checks if http session is active.
	If the http session is expired or user logged off from UI,
	then Modem driver go back to 'run' mode automatically.
]]
function modem:check_session_and_set_automation_mode()
--[[ 	Session is considered as Alive under all these conditions:
		- Ubus RPC session exists and equals to console.session (got from UI)
]]
	local check_result = false

	if checkubus(modem.state.conn, "tsmodem.console", "session") then
		local console_session = util.ubus("tsmodem.console", "session", {})
		if console_session then
			local console_sess = console_session["ubus_rpc_session"] or nil
			local modal_sess = console_session["modal"] or nil


			local ubus_sess = util.ubus("session", "get", {
				ubus_rpc_session = console_sess
			})
			if (ubus_sess and modal_sess == "opened") then
				modem.automation = "stop"
				return
			else
				modem.automation = "run"
				return
			end
		end
	end
	modem.automation = "run"
	return
end



function modem:is_connected(fd)
	return fd and U.isatty(fd)
end

function modem:balance_parsing_and_update(chunk)
	if_debug("balance", "AT", "ANSWER", chunk, "[modem.lua]:balance_parsing_and_update()")

	local ok, err, sim_id = modem.state:get("sim", "value")
    local balance = 0
	if ok then
		local provider_id = get_provider_id(sim_id)
		local ussd_command = uci:get(modem.config_gsm, provider_id, "balance_ussd")
		--local balance_message = ucs2_ascii(BAL_parser:match(chunk))
		balance_message = chunk:sub(13,-7):gsub("'", "\'"):gsub("\n", " "):gsub("%c+", " ")
		balance_message = util.trim(balance_message)

		local balance = BAL_parser(sim_id):match(chunk)

------------------------------------------------------------------------------
-- TODO Решить проблему с USSD session (cancel) и ошибочным форматом сообщений
------------------------------------------------------------------------------

		if (balance and type(balance) == "number") then --[[ if balance value is OK ]]
			modem.state:update("balance", balance, ussd_command, balance_message)
			uci:set(modem.config_gsm, provider_id, "balance_last_message", balance_message)
			uci:commit(modem.config_gsm)
			if_debug("balance", "AT", "ANSWER", balance, "[modem.lua]: Got balance OK.")
		else
			if(#balance_message > 0) then -- If balance message template is wrong
				modem.state:update("balance", "", ussd_command, balance_message)
				if_debug("balance", "AT", "ANSWER", balance_message, "[modem.lua]: balance_message when parsed can't fetch value.")
			elseif(chunk:find("+CUSD: 2") and #chunk <= 12) then -- we need send USSD once again
				modem.state:update("balance", "", ussd_command, balance_message)
				if_debug("balance", "AT", "ANSWER", chunk, "[modem.lua]: chunk when balance_message is empty.")
				return ""
			end
		end

	else
		util.perror('driver.lua : ' .. err)
	end
    return balance
end

function modem:parse_AT_response(chunk)
	if (chunk:find("+CME ERROR") or chunk:find("+CPIN: READY") or chunk:find("+SIMCARD: NOT AVAILABLE")) then
		local cpin = CPIN_parser:match(chunk)
		if cpin then
			modem.state:update("cpin", cpin, "AT+CPIN?", "")
			if_debug("cpin", "AT", "ANSWER", cpin, "[modem.lua]: +CME ERROR, +CPIN: READY or +SIMCARD: NOT AVAILABLE parsed.")
			if (cpin == "false" or cpin == "failure") then return end
		end
	elseif chunk:find("+CREG:") then
		local creg = CREG_parser:match(chunk)
		if_debug("reg", "AT", "ANSWER", creg, "[modem.lua]: +CREG parsed.")
		if creg and creg ~= "" then

			--[[ START PING AND GET BALANCE AS SOON AS SIM REGISTERED AND CONNECTION ESTABLISHED ]]
			--[[ But wait 3 seconds before do it to ensure that the connection is stable ]]
			local ok, err, lastreg = modem.state:get("reg", "value")
			if(lastreg ~= "1" and creg =="1") then

				-- local timer_CUSD_SINCE_SIM_REGISTERED
				-- function t_CUSD_SINCE_SIM_REGISTERED()
				-- 	local ok, err, reg = modem.state:get("reg", "value")
				-- 	if(reg == "1") then
				-- 		if(modem:is_connected(modem.fds)) then
				-- 			local ok_reg, err, reg = modem.state:get("reg", "value")
				-- 			if ok_reg and reg == "1" then
				-- 				local ok_sim, err, sim_id = modem.state:get("sim", "value")
				-- 				if ok_sim and (sim_id == "0" or sim_id =="1") then
				-- 					local provider_id = get_provider_id(sim_id)
				--
				-- 					local ussd_command = string.format("AT+CUSD=2,%s,15\r\n", tostring(uci:get(modem.config_gsm, provider_id, "balance_ussd")))
				-- 					if (modem.debug and (modem.debug_type == "balance" or modem.debug_type == "all")) then print("----->>> Cancel USSD session before start new one: "..ussd_command) end
				--
				-- 					--[[ Stop USSD here while testing other features to avoid USSD blocking ]]
				-- 					local chunk, err, errcode = U.write(modem.fds, ussd_command)
				--
				-- 					local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", tostring(uci:get(modem.config_gsm, provider_id, "balance_ussd")))
				-- 					if (modem.debug and (modem.debug_type == "balance" or modem.debug_type == "all")) then print("----->>> Sending BALANCE REQUEST ASAP SIM REGISTERED: "..ussd_command) end
				-- 					local chunk, err, errcode = U.write(modem.fds, ussd_command)
				--
				-- 					modem.last_balance_request_time = os.time() -- Do it each time USSD request runs
				--
				-- 					modem.timer.PING:set(modem.timer.interval.ping)
				-- 				end
				-- 			end
				-- 		end
				-- 	end
				-- end
				-- timer_CUSD_SINCE_SIM_REGISTERED = uloop.timer(t_CUSD_SINCE_SIM_REGISTERED, 3000)

				-- modem.state:update("balance", balance_event_keys["get-balance-in-progress"], ussd_command, balance_message)	    -- set "in progres" balance state
				-- modem.timer.BAL_TIMEOUT:set(modem.timer.timeout["balance"])					-- clear balance state after timeout
				--
				-- if (modem.debug and (modem.debug_type == "balance" or modem.debug_type == "all")) then print(string.format("[modem.lua]: updated balance state: 'in progress', %s, %s", tostring(ussd_command), tostring(balance_message))) end

			end

			modem.state:update("reg", creg, "AT+CREG?", "")
			modem.state:update("usb", "connected", modem.device .. " open", "")
		end
	elseif chunk:find("+CSQ:") then
		local signal = CSQ_parser:match(chunk)
		if_debug("signal", "AT", "ANSWER", signal, "[modem.lua]: +CSQ parsed every " .. tostring(modem.timer.interval.signal).."ms")
		local no_signal_aliase = {"0", "99", "31", "nil", nil, ""}
		if not util.contains(no_signal_aliase, signal) then
			signal = tonumber(signal) or false
			if (signal and signal > 0 and signal <= 30) then signal = math.ceil(signal * 100 / 31) else signal = "" end
		else
			signal = ""
		end
		modem.state:update("signal", tostring(signal), "AT+CSQ", "")
	elseif chunk:find("+CUSD:") then
		modem:balance_parsing_and_update(chunk)
		--[[ Parse and update 3G/4G mode ]]
	elseif chunk:find("+CNSMOD:") then
		local netmode = CNSMOD_parser:match(chunk) or ""
		if((tonumber(netmode) ~= nil) and tonumber(netmode) <= 16) then
			if(CNSMODES[netmode] ~= nil) then
				modem.state:update("netmode", CNSMODES[netmode]:split("|")[2]:gsub("%s+", "") or "", "AT+CNSMOD?", CNSMODES[netmode])
			else
				modem.state:update("netmode", netmode, "AT+CNSMOD?", CNSMODES["0"])
			end
		end
		if_debug("netmode", "AT", "ANSWER", netmode, "[modem.lua]: parse_AT_response() +NSMOD parsed.")
		-- if (modem.debug and (modem.debug_type == "netmode" or modem.debug_type == "all")) then
		-- 	local cnsmode = CNSMODES[netmode] or " | "
		-- 	print("AT says: ","+NSMOD", tostring(modem.timer.interval.netmode).."ms", cnsmode:split("|")[2]:gsub("%s+", "") or "", "","","","Note: GSM mode")
		-- end
	elseif chunk:find("+NITZ") then
		local pname = provider_name:match(chunk)
		if pname and pname ~= "" then
			modem.state:update("provider_name", pname, "+NITZ", "")
		end
		if_debug("provider", "AT", "ANSWER", pname, "[modem.lua]: parse_AT_response() +NITZ parsed every " .. tostring(modem.timer.interval.provider).."ms.")

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
		end
		if_debug("provider", "AT", "ANSWER", pname, "[modem.lua]: parse_AT_response() +COPS parsed every " .. tostring(modem.timer.interval.provider).."ms.")
	end
end

function modem:send_AT_responce_to_webconsole(chunk)
	-- Send notification only when web-cosole is opened. E.g. when modem automation mode is "stop".
	if modem.automation == "stop" then
		modem.state.conn:notify( modem.state.ubus_methods["tsmodem.driver"].__ubusobj, "AT-answer", {answer = chunk} )
		if (modem.debug and (util.contains(AT_RELATED_UBUS_METHODS, modem.debug_type) or modem.debug_type == "all")) then
			if_debug(modem.debug_type, "UBUS", "NOTIFY", {answer = chunk}, "[modem.lua]: tsmodem.driver notifies subscribers, e.g. when AT-response sent to web-console.")
		end
	end
end

function modem:poll()
	if (modem.fds_ev == nil) and modem:is_connected(modem.fds) then

		modem.fds_ev = uloop.fd_add(modem.fds, function(ufd, events)

			local message_from_browser, message_to_browser = "", ""
			local chunk, err, errcode = U.read(modem.fds, 1024)
			if not err then
				modem:parse_AT_response(chunk)
				modem:send_AT_responce_to_webconsole(chunk)
			else
				if (modem.debug and (util.contains(AT_RELATED_UBUS_METHODS, modem.debug_type) or modem.debug_type == "all")) then
					if_debug(modem.debug_type, "FILE", "POLL", "ERROR", "[modem.lua]: " .. string.format("tsmodem: U.read(modem.fds, 1024) ERROR CODE: %s", tostring(errcode)))
				end
			end

		end, uloop.ULOOP_READ)

	end

end

function modem:unpoll()
	if(modem.fds_ev) then
		modem.fds_ev:delete()
		modem.fds_ev = nil
	end
	if (modem.debug) then print("MODEM UNPOLL") end
end

--[[
Sometime we need to stop automation. For example,
when user click "Setting" of the SIM card in the web UI, then
automation may give him a surprise (switching SIM card while user is editting setting).
To give user a possibility to complete the settings we must stop any automation
]]
function modem:run_automation()
	modem.automation = "run"
end

function modem:stop_automation()
	modem.automation = "stop"
end


-- [[ Initialize ]]
local metatable = {
	__call = function(modem, state, stm, timer)
        modem.state = state
        modem.timer = timer
        modem.stm = stm

        modem.state.init(modem, stm, timer)
        modem.stm.init(modem, state, timer)
        modem.timer.init(modem, state, stm)

        modem.state:make_ubus()

		uloop.init()
		modem:poll()

		timer.general:set(timer.interval.general)
		timer.CPIN:set(timer.interval.cpin)
		timer.CREG:set(timer.interval.reg)
		timer.CSQ:set(timer.interval.signal)
		-- timer.CUSD:set(1000)
		timer.COPS:set(timer.interval.provider)
		timer.CNSMOD:set(timer.interval.netmode)
		timer.PING:set(timer.interval.ping)

		uloop.run()


		state.conn:close()

		return table
	end
}
setmetatable(modem, metatable)

return modem
