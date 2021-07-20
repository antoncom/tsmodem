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

local M = require "posix.termio"
local F = require "posix.fcntl"
local U = require "posix.unistd"

local socket = require "socket"


local config = "ts_modem"
local section = "sim"
local modem = {}
modem.loaded = {}

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
end

function modem:init()
	local fds, err, errnum = F.open("/dev/ttyUSB2", bit.bor(F.O_RDWR, F.O_NONBLOCK))
	if not fds then
		print('Could not open serial port ', err, ':', errnum)
		os.exit(1)
	end

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
end

function modem:make_ubus()
	self.conn = ubus.connect()
	if not self.conn then
		error("Failed to connect to ubus")
	end

	local ubus_objects = {
		["tsmodem.driver"] = {
			level = {
				function(req, msg)
					local chunk, err, errcode = U.write(self.fds, "AT+CSQ\r\n")
					self.conn:reply(req, {rssi="chunk"});			
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			reg = {
				function(req, msg)
					--local chunk, err, errcode = U.write(self.fds, "AT+CREG=2\r\nAT+CREG?\r\n")
					local chunk, err, errcode = U.write(self.fds, "AT+CREG?\r\n")
					self.conn:reply(req, {rssi="chunk"});			
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			AT = {
				function(req, msg)
					--local s = modem:stm32comm(msg["command"]) or self.conn:reply(req, {answer = "Unable to " .. msg["command"]})
					local chunk, err, errcode = U.write(self.fds, msg["command"] .. "\r\n")
					socket.sleep(0.3)
					
					local chunk, err, errcode = U.read(self.fds, 128)
					resp = {[msg.command] = chunk}

					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			STM32 = {
				function(req, msg)

					local s = modem:stm32comm(msg["command"]) or self.conn:reply(req, {answer = "Unable to " .. msg["command"]})
					resp = {[msg.command] = s}

					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			switch = {
				function(req, msg)
					log("switch", msg)
					-- AT: stop AT-protocol requests
					-- and disconnect the driver from the modem port /dev/ttyUSB2
					modem:unpoll()
					socket.sleep(0.5)

					-- STM: switch sim-card
					modem:switch(msg["sim_id"])
			
					-- TODO
					-- Make "dmesg" reading to make delay smaller
					-- and to ensure that serial port is ready
					socket.sleep(12)
					--

					-- Reconnetc the driver to the modem port, start polling
					modem:init()
					modem:poll()

					resp = {["switch"] = "ok"}
					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
	    	-- You get notified when someone subscribes to a channel
			__subscriber_cb = function( subs )
				print("total subs: ", subs )
			end
		}
	}
	self.conn:add( ubus_objects )
	self.ubus_objects = ubus_objects

end

function modem:switch(sim_id)
	print("modem:switch - sim_id", sim_id)
	local s = modem:stm32comm("~0:SIM.SEL=" .. sim_id) or (function()
		log("Unable to ~0:SIM.SEL=" .. sim_id)
		return false
	end)()
	
	socket.sleep(0.2)

	--[[
	It's required to reset modem. Otherwise modem responds with "AT+SIMCARD: NOT AVAILABLE" 
	and serial port is disconnected.
	]]
	s = modem:stm32comm("~0:SIM.RST=0") or log("Unable to reset modem (set low level)")
	print("~0:SIM.RST=0", s)
	if not s then return false end

	socket.sleep(3)

	s = modem:stm32comm("~0:SIM.RST=1") or log("Unable to reset modem (set hight level)")
	print("~0:SIM.RST=1", s)
	if not s then return false end

	return true
end

function modem:stm32comm(comm)
	local buf, value, status = '','',''

	U.write(self.fds_mk, comm .. "\r\n")
	socket.sleep(0.5)
	buf = U.read(self.fds_mk, 128) or 'ERROR: no stm32 buf'

	local b = util.split(buf)
	if(b[#b] == '') then
		table.remove(b, #b)
	end
	
	status = b[#b]
	value = b[1]

	modem:notify("STM-protocol-data", comm .. " : " .. value .. " : " .. status)

	if(status == "OK") then 
		return value 
	else 
		return false 
	end
end

function modem:notify(event_name, event_data)
	self.conn:notify(self.ubus_objects["tsmodem.driver"].__ubusobj, event_name, { message = event_data })
end

function modem:poll()
	self.fds_ev = uloop.fd_add(self.fds, function(ufd, events)
		local chunk, err, errcode = U.read(self.fds, 128)
	    if chunk and (chunk ~= "\n") and (#chunk > 0) then
			modem:notify("AT-protocol-data", chunk)
		elseif(err) then
			error(err) 
		end
	end, uloop.ULOOP_READ)
end

function modem:unpoll()
	self.fds_ev:delete()
	local ok, errmsg = U.close(self.fds)
	if not ok then error (errmsg) end
end


local metatable = { 
	__call = function(table, ...)
		print("__CALL")
		table:init_mk()
		table:init()
		table:make_ubus()
		table:poll()

		uloop.init()

		local timer
		function t()
			print("2000 ms timer");
			timer:set(2000)
		end
		timer = uloop.timer(t)
		timer:set(2000)


		uloop.run()
		table.conn:close()
		return table
	end
}
setmetatable(modem, metatable)
modem()