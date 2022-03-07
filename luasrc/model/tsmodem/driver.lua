--[[
This script has to be made as daemon.
https://oldwiki.archive.openwrt.org/inbox/procd-init-scripts
https://forum.openwrt.org/t/tracking-ubus-listeners/11360
]]

local bit = require "bit"
local lpeg = require "lpeg"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"

local uloop = require "uloop"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

local CREG_parser = require 'luci.model.tsmodem.parser.creg'
local CSQ_parser = require 'luci.model.tsmodem.parser.csq'
local CUSD_parser = require 'luci.model.tsmodem.parser.cusd'
local SMS_parser = require 'luci.model.tsmodem.parser.sms'
local BAL_parser = require 'luci.model.tsmodem.parser.balance'
local ucs2_ascii = require 'luci.model.tsmodem.parser.ucs2_ascii'

local socket = require "socket"


local config = "tsmodem"
local config_gsm = "tsmodem_adapter_provider"
local section = "sim"
local dev = arg[1] or '/dev/ttyUSB1'

local modem = {}
modem.fds = nil
modem.fds_ev = nil
modem.tick_size = 3000

local modem_state = {
	stm = {
--[[	{
			command = "",
			value = "",					-- 0 / 1 / OK / ERROR
			time = "",
			unread = "true"
		}]]
	},
	reg = {
--[[	{
			command = "AT+CREG?",
			value = "",					-- 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7
			time = tostring(os.time()),
			unread = "true"
		}]]
	},
	sim = {
--[[	{
			command = "~0:SIM.SEL=?",
			value = "",					-- 0 / 1
			time = "",
			unread = "true"
		}]]
	},
	signal = {
--[[	{
			command = "AT+CSQ",
			value = "",					-- 0..31
			time = "",
			unread = "true"
		}]]
	},
	balance = {
--[[	{
			command = "*100#",
			value = "605",
			time = "1646539246",
			unread = "true"
		}]]
	},
	usb = {
--[[	{
			command = "", 				-- /dev/ttyUSB open  |  /dev/ttyUSB close
			value = "",					-- connected / disconnected
			time = "",
			unread = "true"
		}]]
	},
}

--[[ Example:
--   local ok, error, value = modem:get_state("sim", value)
]]
function modem:get_state(var, param)
	local value = ""
	local v, p = tostring(var), tostring(param)
	if modem_state[v] and (#modem_state[v] > 0) and modem_state[v][#modem_state[v]][p] then
		value = modem_state[v][#modem_state[v]][p]
		return true, "", value
	else
		return false, string.format("State Var '%s' or Param '%s' are not found in list of state vars.", v, p), value
	end
end

--[[
Get provider Id from uci config
]]

function modem:get_provider_id(sim_id)
	local provider_id
	if (sim_id and (sim_id == "0" or sim_id == "1")) then
		provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	end
	return provider_id or ""
end

function modem:init_mk()
	local sys  = require "luci.sys"
	sys.exec("stty -F /dev/ttyS1 1000000")
	socket.sleep(0.5)
	local fds_mk, err, errnum = F.open("/dev/ttyS1", bit.bor(F.O_RDWR, F.O_NONBLOCK))
	if not fds_mk then
		print('Could not open serial port ', err, ':', errnum)
		os.exit(1)
	end

	M.tcsetattr(fds_mk, 0, {
	   cflag = 0x1008 + M.CS8 + M.CLOCAL + M.CREAD,
	   iflag = M.IGNPAR,
	   oflag = M.OPOST,
	   cc = {
	      [M.VTIME] = 0,
	      [M.VMIN] = 1,
	   }
	})
	self.fds_mk = fds_mk

	local res, sim_id = modem:stm32comm("~0:SIM.SEL=?")
	if res == "OK" then
		modem:update_state("sim", tostring(sim_id), "~0:SIM.SEL=?")
	else
		-- TODO: log error
	end
end

function modem:init()
	if not self:is_connected(self.fds) then

		modem:unpoll()
		if self.fds then
			U.close(self.fds)

			modem:update_state("usb", "disconnected", dev .. " close")
			modem:update_state("reg", "7", "AT+CREG?")
			modem:update_state("signal", "0", "AT+CSQ")
		end

		local fds, err, errnum = F.open(dev, bit.bor(F.O_RDWR, F.O_NONBLOCK))

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
			self.fds = fds

			modem:update_state("usb", "connected", dev .. " open")
			modem:update_state("reg", "7", "AT+CREG?")
			modem:update_state("signal", "0", "AT+CSQ")
			modem.state.reg.time = tostring(os.time())

		end

	end
end

function modem:make_ubus()
	self.conn = ubus.connect()
	if not self.conn then
		error("Failed to connect to ubus")
	end

	-- Сделать перебор очереди статусов, проверяя параметр "unread"
	-- и выдавать до тех пор пока unread==true

	function getFirstUnread(name)
		local n = #modem.state[name]
		if n > 0 then
			for i=1, #modem.state[name] do
				if modem.state[name][i].unread == "true" then
					return modem.state[name][i]
				end
			end
			-- If no unread states then return the last one.
			return modem.state[name][n]
		end
		return {}
	end

	function makeResponse(name)
		local r, resp = {}, {}
		local n = #modem.state[name]
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

	local ubus_objects = {
		["tsmodem.driver"] = {
			reg = {
				function(req, msg)
					local resp = makeResponse("reg")
					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			sim = {
				function(req, msg)
					local resp = makeResponse("sim")
					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			signal = {
				function(req, msg)
					local resp = makeResponse("signal")
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			balance = {
				function(req, msg)
					local resp = makeResponse("balance")
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},

			do_request_ussd_balance = {
				function(req, msg)
					local sim_id_settings = msg["sim_id"]
					local ok, err, sim_id = modem:get_state("sim", "value")
					if(sim_id_settings == sim_id) then
						local provider_id = uci:get(config, "sim_" .. sim_id, "provider")
						local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(config_gsm, provider_id, "balance_ussd"))

						modem:update_state("balance", "", ussd_command, uci:get(config_gsm, provider_id, "balance_last_message"))

						local chunk, err, errcode = U.write(modem.fds, ussd_command)
					end
					local resp = {}

					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},

			usb = {
				function(req, msg)
					local resp = makeResponse("usb")
					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},

			stm = {
				function(req, msg)
					local resp = makeResponse("stm")
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},

			do_switch = {
				function(req, msg)
					local resp, n = {}, 0

					local res, sim_id = modem:stm32comm("~0:SIM.SEL=?")
					if res == "OK" then
						modem:update_state("sim", tostring(sim_id), "~0:SIM.SEL=?")
					else
						-- TODO: log error
					end

					if self:is_connected(self.fds) then
						n = #modem.state.usb
						if (modem.state.usb[n].value ~= "disconnected") then

							modem:unpoll()
							socket.sleep(0.5)

							n = #modem.state.sim
							if(modem.state.sim[n].value == "0") then
								modem:switch("1")
							else
								modem:switch("0")
							end
							resp = makeResponse("sim")
						else
							resp = makeResponse("sim")
							resp.value = "not-ready-to-switch"
						end

					end


					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
		}
	}
	self.conn:add( ubus_objects )
	self.ubus_objects = ubus_objects

end


function modem:update_state(param, value, command, comment)
	local newval = tostring(value)

	local n = #modem.state[param]

	if (n == 0) then
		local item = {
			["command"] = command,
			["value"] = newval,
			["time"] = tostring(os.time()),
			["unread"] = "true",
			["comment"] = comment
		}
		modem.state[param][1] = util.clone(item)
	elseif (n >= 1) then
		if(modem.state[param][n].value ~= newval or modem.state[param][n].command ~= command) then
			local item = {
				["command"] = command,
				["value"] = newval,
				["time"] = tostring(os.time()),
				["unread"] = "true",
				["comment"] = comment
			}
			modem.state[param][n+1] = util.clone(item)
			if n > 5 then
				table.remove(modem.state[param], 1)
			end
		--[[ Update last time of succesful registration state ]]
		elseif (param == "reg" and (newval == "1" or newval == "7")) then
			modem.state["reg"][n].time = tostring(os.time())
			--[[ Update time of last balance ussd request if balance's value is not changed ]]
		elseif (param == "balance") then
			modem.state["balance"][n].time = tostring(os.time())
		end
	end
end

function modem:is_connected(fd)
	return fd and U.isatty(fd)
end

function modem:switch(sim_id)

	local res, val = modem:stm32comm("~0:SIM.SEL=" .. tostring(sim_id))
	if res == "OK" then

		modem:update_state("sim", sim_id, "~0:SIM.SEL=" .. tostring(sim_id), "")
		modem:update_state("stm", "OK", "~0:SIM.SEL=" .. tostring(sim_id), "")

		--[[
		Lets update network interface APN
		]]

		local provider_id = uci:get(config, "sim_" .. sim_id, "provider")
		local apn = uci:get(config_gsm, provider_id, "gate_address")
		uci:set("network", "tsmodem", "apn", apn)
		uci:save("network")
		uci:commit("network")

	else
		modem:update_state("stm", "ERROR", "~0:SIM.SEL=" .. tostring(sim_id))
	end

	socket.sleep(0.4)

	modem:update_state("reg", "7", "AT+CREG?", "")
	modem:update_state("signal", "", "", "")
	modem:update_state("balance", "", "", "")

	res, val = modem:stm32comm("~0:SIM.RST=0")
	if res == "OK" then

		modem:update_state("stm", "OK", "~0:SIM.RST=0", "")
		modem:update_state("usb", "disconnected", dev .. " close", "")

	else

		modem:update_state("stm", "ERROR", "~0:SIM.RST=0", "")
		modem:update_state("usb", "disconnected", dev .. " close", "")

	end

	socket.sleep(0.8)

	res, val = modem:stm32comm("~0:SIM.RST=1")
	if res == "OK" then

		modem:update_state("stm", "OK", "~0:SIM.RST=1", "")
		modem:update_state("usb", "disconnected", dev .. " close", "")

	else

		modem:update_state("stm", "ERROR", "~0:SIM.RST=1", "")
		modem:update_state("usb", "disconnected", dev .. " close", "")

	end
	socket.sleep(0.4)
end

--[[
	local uci_result, section = false, "sim_" .. sim_id
	uci_result = uci:set("tsmodem", "sim_0", "status", "0")-- or error('uci set error: ' .. "tsmodem" .. ' sim_0 status => 0')
	uci_result = uci:set("tsmodem", "sim_1", "status", "0")--  or error('uci set error: ' .. "tsmodem" .. ' sim_1 status => 0')
	uci_result = uci:set("tsmodem", section , "status", sim_id)--  or error('uci set error: ' .. "tsmodem" .. ' ' .. section .. ' status: ' .. sim_id)
	uci_result = uci:commit("tsmodem")-- or error('uci commit error, sim_id: ' .. sim_id)
]]

function modem:stm32comm(comm)
	local buf, value, status = '','',''

	U.write(self.fds_mk, comm .. "\r\n")
	socket.sleep(0.1)
	buf = U.read(self.fds_mk, 1024) or error('ERROR: no stm32 buf')

	local b = util.split(buf)
	if(b[#b] == '') then
		table.remove(b, #b)
	end

	status = b[#b]
	value = b[1]


	if(status == "OK") then
		return status, value
	else
		return "ERROR"
	end
end

function modem:balance_parsing_and_update(chunk)
	local ok, err, sim_id = modem:get_state("sim", "value")

	if ok then
		local provider_id = modem:get_provider_id(sim_id)
		local ussd_command = uci:get("tsmodem_adapter_provider", provider_id, "balance_ussd")

		local balance_message = ucs2_ascii(CUSD_parser:match(chunk))
		balance_message = string.gsub(balance_message, ",", ".")

		local balance = BAL_parser(sim_id):match(balance_message) or ""

		if (balance and balance ~= "") then --[[ if balance value is OK ]]
			modem:update_state("balance", balance, ussd_command, balance_message)
			uci:set("tsmodem_adapter_provider", provider_id, "balance_last_message", balance_message)
			uci:commit("tsmodem_adapter_provider")
		else
			if(#balance_message > 0) then -- If balance message template is wrong
				modem:update_state("balance", "-999", ussd_command, "A mistake in balance message template.")
				uci:set("tsmodem_adapter_provider", provider_id, "balance_last_message", balance_message)
				uci:commit("tsmodem_adapter_provider")
			elseif(chunk:find("+CUSD: 2")) then -- GSM net cancels USSD sesion
				modem:update_state("balance", "-998", ussd_command, "GSM provider cancels USSD session. We will get balance later.")
			end
		end

	else
		util.perror('driver.lua : ' .. err)
	end
end

function modem:poll()
	if (not self.fds_ev) and modem:is_connected(self.fds) then

		self.fds_ev = uloop.fd_add(self.fds, function(ufd, events)

			local chunk, err, errcode = U.read(self.fds, 1024)
		    if chunk:find("+CREG:") then
		    	--print("CREG: ", chunk)
		    	local creg = CREG_parser:match(chunk)
		    	if creg and creg ~= "" then
					--[[ GET BALANCE AS SOON AS SIM REGISTERED AND CONNECTION ESTABLISHED ]]
					local ok, err, lastreg = modem:get_state("reg", "value")
					if(lastreg ~= "1" and creg =="1") then
						local ok, err, sim_id = modem:get_state("sim", "value")
						if ok then
							if(sim_id == "0" or sim_id =="1") then
								local get_balance_delay = 180 -- 3 mins
								local ok, err, last_balance_time = modem:get_state("balance", "time")
								if not tonumber(last_balance_time) then
									last_balance_time = 0
								end

								local provider_id = uci:get(config, "sim_" .. sim_id, "provider")
								local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(config_gsm, provider_id, "balance_ussd"))
								local chunk, err, errcode = U.write(modem.fds, ussd_command)
							end
						else
							util.perror("ERROR: sim or value not found in state.")
						end

					end


	    			modem:update_state("reg", creg, "AT+CREG?", "")
	    			modem:update_state("usb", "connected", dev .. " open", "")
				end
			elseif chunk:find("+CSQ:") then
				--print("CSQ: ", chunk)
				local signal = CSQ_parser:match(chunk)
				if signal and signal ~= "" then

					--print("signal: ", signal)
					modem:update_state("signal", signal, "AT+CSQ", "")

				end
			elseif chunk:find("+CUSD:") then
				modem:balance_parsing_and_update(chunk)
			elseif(err) then
				error(err)
			end

		end, uloop.ULOOP_READ)
	end
end

function modem:unpoll()
	if(self.fds_ev) then
		self.fds_ev:delete()
		self.fds_ev = nil
	end
end


local metatable = {
	__call = function(table, ...)
		table.state = modem_state

		table:make_ubus()
		table:init_mk()

		uloop.init()
		modem:poll()

		local timer
		function t()
			modem:init()
			modem:poll()

			timer:set(modem.tick_size)
		end
		timer = uloop.timer(t)
		timer:set(modem.tick_size)


		local timer_CREG
		function t_CREG()
			if(modem:is_connected(modem.fds)) then
				local chunk, err, errcode = U.write(modem.fds, "AT+CREG?" .. "\r\n")
			end

			timer_CREG:set(3000)
		end
		timer_CREG = uloop.timer(t_CREG)
		timer_CREG:set(3000)


		local timer_CSQ
		function t_CSQ()
			if(modem:is_connected(modem.fds)) then
				local chunk, err, errcode = U.write(modem.fds, "AT+CSQ" .. "\r\n")
			end

			timer_CSQ:set(5000)
		end
		timer_CSQ = uloop.timer(t_CSQ)
		timer_CSQ:set(5000)


		local timer_CUSD
		function t_CUSD()
			if(modem:is_connected(modem.fds)) then
				--[[ Get balance only if SIM is registered in the GSM network ]]

				local ok, err, reg = modem:get_state("reg", "value")
				if ok and reg == "1" then
					local ok, err, sim_id = modem:get_state("sim", "value")
					if ok then
						if(sim_id == "0" or sim_id =="1") then
							local get_balance_delay = 180 -- 3 mins
							local ok, err, last_balance_time = modem:get_state("balance", "time")
							if (tonumber(last_balance_time) and (last_balance_time ~= "0")) then
								local timecount = os.time() - tonumber(last_balance_time)
								if( timecount > get_balance_delay ) then
									local provider_id = uci:get(config, "sim_" .. sim_id, "provider")
									local ussd_command = string.format("AT+CUSD=1,%s,15\r\n", uci:get(config_gsm, provider_id, "balance_ussd"))
									local chunk, err, errcode = U.write(modem.fds, ussd_command)
								end
							end
							timer_CUSD:set(3000)
						end
					else
						util.perror("ERROR: sim or value not found in state.")
					end
				else
					timer_CUSD:set(3000)
				end
			else
				timer_CUSD:set(3000)
			end
		end
		timer_CUSD = uloop.timer(t_CUSD)
		timer_CUSD:set(6000)

		uloop.run()
		table.conn:close()
		return table
	end
}
setmetatable(modem, metatable)
modem()
