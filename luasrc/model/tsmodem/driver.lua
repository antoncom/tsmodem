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

local socket = require "socket"


local config = "tsmodem"
local section = "sim"
local dev = arg[1] or '/dev/ttyUSB2'

local modem = {}
modem.fds = nil
modem.fds_ev = nil
modem.tick_size = 3000

local modem_state = {
	stm = {
		command = "",
		value = "",					-- 0 / 1 / OK / ERROR
		time = "",
	},
	reg = {
		command = "AT+CREG?",
		value = "",					-- 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7
		time = tostring(os.time())
	},
	sim = {
		command = "~0:SIM.SEL=?",
		value = "",					-- 0 / 1
		time = ""
	},
	signal = {
		command = "AT+CSQ",
		value = "",					-- 0..31
		time = ""
	},
	balance = {
		command = "__TODO__",
		value = "",
		time = ""
	},
	usb = {
		command = "", 				-- /dev/ttyUSB open  |  /dev/ttyUSB close
		value = "",					-- connected / disconnected
		time = ""
	},
}

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

			modem:update_state("usb", "disconnected", "/dev/ttyUSB2 close")
			modem:update_state("reg", "7", "AT+CREG?")
			modem:update_state("signal", "0", "AT+CSQ")
		end

		local fds, err, errnum = F.open("/dev/ttyUSB2", bit.bor(F.O_RDWR, F.O_NONBLOCK))

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

			modem:update_state("usb", "connected", "/dev/ttyUSB2 open")
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

	local ubus_objects = {
		["tsmodem.driver"] = {
			reg = {
				function(req, msg)
					
					local resp = { 
						command = modem.state.reg.command,
						value = modem.state.reg.value, 
						time = modem.state.reg.time 
					}
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			sim = {
				function(req, msg)
					
					local resp = { 
						command = modem.state.sim.command,
						value = modem.state.sim.value, 
						time = modem.state.sim.time 
					}
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			signal = {
				function(req, msg)
					
					local resp = { 
						command = modem.state.signal.command,
						value = modem.state.signal.value, 
						time = modem.state.signal.time 
					}
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			balance = {
				function(req, msg)
					
					local resp = { 
						command = modem.state.balance.command,
						value = modem.state.balance.value, 
						time = modem.state.balance.time 
					}
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			usb = {
				function(req, msg)
					
					local resp = { 
						command = modem.state.usb.command,
						value = modem.state.usb.value, 
						time = modem.state.usb.time,
					}
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},

			stm = {
				function(req, msg)
					
					local resp = { 
						command = modem.state.stm.command,
						value = modem.state.stm.value, 
						time = modem.state.stm.time,
					}
					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},

			do_switch = {
				function(req, msg)

					if self:is_connected(self.fds) then
						
						if (modem.state.usb.value ~= "disconnected") then 

							modem:unpoll()
							socket.sleep(0.5)
						
							if(modem.state.sim.value == "0") then
								modem:switch("1")
							else
								modem:switch("0")
							end

							resp = { value = modem.state.sim.value, time = modem.state.sim.time}
						else
							resp = { value = "not-ready-to-switch", time = modem.state.sim.time}
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

function modem:update_state(param, value, command)
	local newval = tostring(value)
	-- Update time of each parameters if value or command changed
	-- And always update for "reg" parameter
	if(modem.state[param].value ~= newval or modem.state[param].command ~= command or param == "reg") then
		modem.state[param].value = newval
		modem.state[param].command = command


		-- Update time of registration if only OK (1), or modem disconnected from USB (7)
		if(param ~= "reg") then
			modem.state[param].time = tostring(os.time())
		else
			if(newval == "1" or newval == "7") then
				modem.state[param].time = tostring(os.time())
			end
		end
	end
end

function modem:is_connected(fd)
	return fd and U.isatty(fd)
end

function modem:switch(sim_id)

	modem:update_state("reg", "7", "AT+CREG?")
	modem:update_state("signal", "0", "AT+CSQ")

	local res, val = modem:stm32comm("~0:SIM.SEL=" .. tostring(sim_id))
	if res == "OK" then

		modem:update_state("sim", sim_id, "~0:SIM.SEL=" .. tostring(sim_id))
		modem:update_state("stm", "OK", "~0:SIM.SEL=" .. tostring(sim_id))

	else
		modem:update_state("stm", "ERROR", "~0:SIM.SEL=" .. tostring(sim_id))
	end

	socket.sleep(0.4)

	res, val = modem:stm32comm("~0:SIM.RST=0")
	if res == "OK" then

		modem:update_state("stm", "OK", "~0:SIM.RST=0")
		modem:update_state("usb", "disconnected", "/dev/ttyUSB2 close")


	else

		modem:update_state("stm", "ERROR", "~0:SIM.RST=0")
		modem:update_state("usb", "disconnected", "/dev/ttyUSB2 close")

	end

	socket.sleep(0.8)

	res, val = modem:stm32comm("~0:SIM.RST=1")
	if res == "OK" then

		modem:update_state("stm", "OK", "~0:SIM.RST=1")
		modem:update_state("usb", "disconnected", "/dev/ttyUSB2 close")

	else

		modem:update_state("stm", "ERROR", "~0:SIM.RST=1")
		modem:update_state("usb", "disconnected", "/dev/ttyUSB2 close")

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


--function modem:notify(event_name, event_data)
--	self.conn:notify(self.ubus_objects["tsmodem.driver"].__ubusobj, event_name, event_data )
--end

function modem:poll()
	if (not self.fds_ev) and modem:is_connected(self.fds) then

		self.fds_ev = uloop.fd_add(self.fds, function(ufd, events)

			local chunk, err, errcode = U.read(self.fds, 1024)

		    if chunk:find("+CREG:") then

		    	--print("CREG: ", chunk)
		    	local creg = CREG_parser:match(chunk)
		    	if creg and creg ~= "" then

		    		--print("creg: ", creg)

	    			modem:update_state("reg", creg, "AT+CREG?")
	    			modem:update_state("usb", "connected", "/dev/ttyUSB2 open")

				end
			elseif chunk:find("+CSQ:") then
				--print("CSQ: ", chunk)
				local signal = CSQ_parser:match(chunk)
				if signal and signal ~= "" then

					--print("signal: ", signal)
					modem:update_state("signal", signal, "AT+CSQ")

				end
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


		uloop.run()
		table.conn:close()
		return table
	end
}
setmetatable(modem, metatable)
modem()
