
local socket = require "socket"
local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

-- Constants & utils
local CNSMODES = require 'tsmodem.constants.cnsmodes'
require "tsmodem.util.split_string"
require "tsmodem.driver.util"

-- Paesers
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
modem.debug = true
modem.debug_type = uci:get("tsmodem", "debug", "type")

modem.device = arg[1] or '/dev/ttyUSB1'         -- First port
modem.fds = nil                                 -- File descriptor for /dev/ttyUSB2
modem.fds_ev = nil      						-- Event loop descriptor

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

			modem.state:update("usb", "connected", modem.device .. " open", "")
			modem.state:update("reg", "7", "AT+CREG?", "")
			modem.state:update("signal", "", "AT+CSQ", "")
            modem.state:update("reg", "", "AT+CSQ", "")
			modem.state:update("switching","false", "","")


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
		end
	end
end



function modem:is_connected(fd)
	return fd and U.isatty(fd)
end

function modem:balance_parsing_and_update(chunk)
	local ok, err, sim_id = modem.state:get("sim", "value")
    local balance = 0
	if ok then
		local provider_id = get_provider_id(sim_id)
		local ussd_command = uci:get(modem.config_gsm, provider_id, "balance_ussd")
		--local balance_message = ucs2_ascii(BAL_parser:match(chunk))
		balance_message = chunk:sub(13,-7):gsub("'", "\'"):gsub("\n", " "):gsub("%c+", " ")
		balance_message = util.trim(balance_message)

print("BAL chunk, sim_id:", chunk, sim_id)
		local balance = BAL_parser(sim_id):match(chunk)


		if (balance and type(balance) == "number") then --[[ if balance value is OK ]]
			modem.state:update("balance", balance, ussd_command, balance_message)
			uci:set(modem.config_gsm, provider_id, "balance_last_message", balance_message)
			uci:commit(modem.config_gsm)
		else
			if(#balance_message > 0) then -- If balance message template is wrong
				--modem.state:update("balance", "-999", ussd_command, "A mistake in balance message template.")
				modem.state:update("balance", "", ussd_command, balance_message)
				uci:set(modem.config_gsm, provider_id, "balance_last_message", balance_message)
				uci:commit(modem.config_gsm)
			-- elseif(chunk:find("+CUSD: 2")) then -- GSM net cancels USSD sesion
			-- 	if (modem.debug and modem.debug_type == "balance") then print("AT says: ","+CUSD: 2", tostring(modem.timer.interval.balance).."ms", 2, "","","","GSM provider cancels USSD session.") end
			-- 	modem.state:update("balance", "", ussd_command, "GSM provider cancels USSD session. We will get balance later.")
			end
		end

	else
		util.perror('driver.lua : ' .. err)
	end
    return balance
end

function modem:poll()
	if (modem.fds_ev == nil) and modem:is_connected(modem.fds) then
		modem.fds_ev = uloop.fd_add(modem.fds, function(ufd, events)
			local chunk, err, errcode = U.read(modem.fds, 1024)
			if not err then
				if chunk:find("+CREG:") then
					local creg = CREG_parser:match(chunk)
	                if (modem.debug and modem.debug_type == "reg") then print("AT says: ","+CREG", tostring(modem.timer.interval.reg).."ms", creg, "","","","Note: Sim registration state (0..5)") end
					if creg and creg ~= "" then

						--[[ START PING AND GET BALANCE AS SOON AS SIM REGISTERED AND CONNECTION ESTABLISHED ]]
	                    --[[ But wait 3 seconds before do it to ensure that the connection is stable ]]
	                    local ok, err, lastreg = modem.state:get("reg", "value")
						if(lastreg ~= "1" and creg =="1") then

	                        local timer_CUSD_SINCE_SIM_REGISTERED
	                		function t_CUSD_SINCE_SIM_REGISTERED()
								local ok, err, reg = modem.state:get("reg", "value")
								if(reg == "1") then
		                			if(modem:is_connected(modem.fds)) then
		                				local ok_reg, err, reg = modem.state:get("reg", "value")
		                				if ok_reg and reg == "1" then
		                					local ok_sim, err, sim_id = modem.state:get("sim", "value")
		                					if ok_sim and (sim_id == "0" or sim_id =="1") then
		                                        local provider_id = get_provider_id(sim_id)

												-- local ussd_command = string.format("AT+CUSD=2,%s,15\r\n", uci:get(modem.config_gsm, provider_id, "balance_ussd"))
												-- if (modem.debug and modem.debug_type == "balance") then print("----->>> Cancel USSD session before start new one: "..ussd_command) end
												-- local chunk, err, errcode = U.write(modem.fds, ussd_command)

												local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(modem.config_gsm, provider_id, "balance_ussd"))
												if (modem.debug and modem.debug_type == "balance") then print("----->>> Sending BALANCE REQUEST ASAP SIM REGISTERED: "..ussd_command) end
												local chunk, err, errcode = U.write(modem.fds, ussd_command)

												modem.last_balance_request_time = os.time() -- Do it each time USSD request runs

												modem.timer.PING:set(modem.timer.interval.ping)
		                                    end
		                                end
		                            end
								end
	                		end
	                		timer_CUSD_SINCE_SIM_REGISTERED = uloop.timer(t_CUSD_SINCE_SIM_REGISTERED, 3000)
	                    end

	                    modem.state:update("reg", creg, "AT+CREG?", "")
	                    modem.state:update("usb", "connected", modem.device .. " open", "")
					end
				elseif chunk:find("+CSQ:") then
					local signal = CSQ_parser:match(chunk)
					if (modem.debug and modem.debug_type == "signal") then print("AT says: ","+CSQ", tostring(modem.timer.interval.signal).."ms", tostring(CSQ_parser:match(chunk)),"","","","Note: Signal strength, 0..31") end
					local no_signal_aliase = {"0", "99", "31", "nil", nil, ""}
					if not util.contains(no_signal_aliase, signal) then
						signal = tonumber(signal) or false
						if (signal and signal > 0 and signal <= 30) then signal = math.ceil(signal * 100 / 31) else signal = "" end
					else
						signal = ""
					end
					modem.state:update("signal", tostring(signal), "AT+CSQ", "")
				elseif chunk:find("+CUSD:") then
					local bal = modem:balance_parsing_and_update(chunk)
	                if (modem.debug and modem.debug_type == "balance") then print("AT says: ","+CUSD", tostring(modem.timer.interval.balance).."ms", bal, "","","",chunk) end
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
	                if (modem.debug and modem.debug_type == "netmode") then
	                    local cnsmode = CNSMODES[netmode] or " | "
	                    print("AT says: ","+NSMOD", tostring(modem.timer.interval.netmode).."ms", cnsmode:split("|")[2]:gsub("%s+", "") or "", "","","","Note: GSM mode")
	                end
				elseif chunk:find("+NITZ") then
					local pname = provider_name:match(chunk)
					if pname and pname ~= "" then
						modem.state:update("provider_name", pname, "+NITZ", "")
					end
	                if (modem.debug and modem.debug_type == "provider") then print("AT says: ","+NITZ", tostring(modem.timer.interval.provider).."ms", pname, "","","","Note: Cell provider name") end
	            elseif chunk:find("+COPS:") then
					local pcode = chunk:split('\"')
	                local pname = ""
					if pcode and pcode[2] then
	                    uci:foreach(modem.config_gsm, "adapter", function(sec)
	                        if sec.code == pcode[2] then
	                            pname = sec.name
	                            modem.state:update("provider_name", pname, "AT+COPS?", "")
	                        end
	                    end)
					end
	                if (modem.debug and modem.debug_type == "provider") then print("AT says: ","+COPS", tostring(modem.timer.interval.provider).."ms", pname, "","","","Note: Cell provider name") end
				end
			else
				print(string.format("tsmodem: U.read(modem.fds, 1024) ERROR CODE: %s", tostring(errcode)))
			end

		end, uloop.ULOOP_READ)

		-- if (modem.fds_ev) then
		-- 	if (modem.debug) then print("MODEM POLL STARTED") end
		-- end

	end

end

function modem:unpoll()
	if(modem.fds_ev) then
		modem.fds_ev:delete()
		modem.fds_ev = nil
	end
	if (modem.debug) then print("MODEM UNPOLL") end
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
		timer.CREG:set(timer.interval.reg)
		timer.CSQ:set(timer.interval.signal)
		timer.CUSD:set(1000)
		timer.COPS:set(timer.interval.provider)
		timer.CNSMOD:set(timer.interval.netmode)

        uloop.run()
		state.conn:close()

		return table
	end
}
setmetatable(modem, metatable)

return modem
