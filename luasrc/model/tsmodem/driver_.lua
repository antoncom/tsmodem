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
local nixio = require "nixio"

local uloop = require "uloop"

local M = require "posix.termio"
local F = require "posix.fcntl"
local U = require "posix.unistd"

local socket = require "socket"


local config = "ts_modem"
local section = "sim"
local modem = {}
modem.loaded = {}

local AT = {
	port = "/dev/ttyUSB2",
	rate = "115200"
}

local MK = {
	port = "/dev/ttyS1",
	rate = "1000000"
}

function modem:init_mk()
	local sys  = require "luci.sys"
	sys.exec("stty -F /dev/ttyS1 1000000")

	local fds_mk, err, errnum = F.open("/dev/ttyS1", bit.bor(F.O_RDWR, F.O_NOCTTY, F.O_NONBLOCK))
	if not fds_mk then
		print('Could not open serial port ', err, ':', errnum)
		os.exit(1)
	end
	self.fds_mk = fds_mk
end

function modem:init()
	local fds, err, errnum = F.open("/dev/ttyUSB2", bit.bor(F.O_RDWR, F.O_NOCTTY, F.O_NONBLOCK))
	if not fds then
		print('Could not open serial port ', err, ':', errnum)
		os.exit(1)
	end
	self.fds = fds
end

function modem:make_ubus()
	self.conn = ubus.connect()
	if not self.conn then
		error("Failed to connect to ubus")
	end

	local ubus_objects = {
		tsmodem = {
			level = {
				function(req, msg)
					local chunk, err, errcode = U.write(self.fds, "AT+CSQ\r\n")
					self.conn:reply(req, {rssi="chunk"});			
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			switch = {
				function(req, msg)
					-- AT: stop AT-protocol requests
					modem:unpoll()
					socket.sleep(0.5)
					-- STM: switch sim-card
					modem:switch()
					-- STM: send modem reset high
					-- STM: send modem reset low
					-- UBUS: subscribe
					-- AT: start AT-protocol requests
					-- self.conn:reply(req, {answer="uloop.done()"});			
					-- local d = uloop.fd_remove(table.fds)
					
					socket.sleep(10)
					print("POLL AGAIN")
					modem:poll()

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

function modem:switch()
	local s = modem:stm32comm("~0:SIM.SEL=?") or log("Unable to change SIM card")
	if(s == "0") then
		s = modem:stm32comm("~0:SIM.SEL=1") or log("Unable to select SIM #1")
	elseif(s == "1") then
		s = modem:stm32comm("~0:SIM.SEL=0") or log("Unable to select SIM #0")
	else return false end
	
	socket.sleep(0.2)

	s = modem:stm32comm("~0:SIM.RST=0") or log("Unable to reset modem (set low level)")
	if not s then return s end

	socket.sleep(10)

	s = modem:stm32comm("~0:SIM.RST=1") or log("Unable to reset modem (set hight level)")
	if not s then return s end
	return true
end

function modem:stm32comm(comm)
	local value, status
	U.write(self.fds_mk, comm .. "\r\n")
	socket.sleep(0.5)
	value = U.read(self.fds_mk, 128):sub(1, -2) -- remove \n
	status = U.read(self.fds_mk, 128)
	status = status and status:sub(1,-2) or "OK" -- enforce ok-status if no status presented from STM32
	
	self.conn:notify(self.ubus_objects.tsmodem.__ubusobj, "STM-protocol data", {command = comm, result = value, status = status})

	if(status == "OK") then 
		return value 
	else 
		return false 
	end
end

function modem:poll()
	self.fds_ev = uloop.fd_add(self.fds, function(ufd, events)
		local chunk, err, errcode = U.read(self.fds, 128)
	    if chunk then
			self.conn:notify(self.ubus_objects.tsmodem.__ubusobj, "AT-protocol data", {message = chunk})
		elseif(err) then
			error(err) 
		end
	end, uloop.ULOOP_READ)
end

function modem:unpoll()
	self.fds_ev:delete()
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