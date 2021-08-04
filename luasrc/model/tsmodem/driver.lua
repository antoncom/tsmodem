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


local config = "tsmodem"
local section = "sim"

local modem = {}
modem.loaded = {}
modem.fds = nil
modem.tick_size = 200

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
	if not self.fds then

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
			modem:notify("STM32", { command = "GSM-attach", response = "CONNECTED" })

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
					local resp = {}

					if(self.fds) then
						
						local chunk, err, errcode = U.write(self.fds, msg["command"] .. "\r\n")

						socket.sleep(0.3)					
						
						local at_response, err, errcode = U.read(self.fds, 128)
						local chunk = at_response or ""

						resp = {[msg.command] = chunk}

						modem:notify("AT", { command = msg["command"], response = chunk })
						self.conn:reply(req, resp);

					else
						self.conn:reply(req, { command = msg["command"], response = chunk });
					end

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			STM32 = {
				function(req, msg)

					local s = modem:stm32comm(msg["command"])
					resp = {[msg.command] = s}

					self.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			switch = {
				function(req, msg)
					if(self.fds) then
						local ok, errmsg = U.close(self.fds)
						if ok then 
						
							socket.sleep(0.5)
							self.fds = nil

							modem:notify("STM32", { command = "GSM-attach", response = "DISCONNECTED" })
							modem:switch(msg["sim_id_switch_to"])
							resp = {["switch"] = "switching-in-progress"}	

						else

							resp = {["switch"] = "ERROR: /dev/ttyUSB2: " .. errmsg}	
							modem:notify("STM32", { command = "GSM-attach", response = "/dev/ttyUSB2 DISCONNECT ERROR" })

						end
					else
						resp = {["switch"] = "switching-in-progress"}
					end

					self.conn:reply(req, resp);

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
		}
	}
	self.conn:add( ubus_objects )
	self.ubus_objects = ubus_objects

end

function modem:switch(sim_id)

	modem:stm32comm("~0:SIM.SEL=" .. tostring(sim_id))
	socket.sleep(0.1)

	modem:stm32comm("~0:SIM.RST=0")
	socket.sleep(1)

	modem:stm32comm("~0:SIM.RST=1")
	socket.sleep(0.1)

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

--	print("COMM: " .. comm)
	U.write(self.fds_mk, comm .. "\r\n")
	socket.sleep(0.1)
	buf = U.read(self.fds_mk, 128) or error('ERROR: no stm32 buf')

	local b = util.split(buf)
	if(b[#b] == '') then
		table.remove(b, #b)
	end
	
	status = b[#b]
	value = b[1]

	if(value == status) then
		modem:notify("STM32", { command = comm,  response = "", ["status"] = status })
--		if (comm == "~0:SIM.SEL=1" or comm == "~0:SIM.SEL=1") then
--			log("_________ stm32comm _______", comm)
--		end
	else
		modem:notify("STM32", { command = comm,  response = value, ["status"] = status })
--		if (comm == "~0:SIM.SEL=1" or comm == "~0:SIM.SEL=1") then
--			log("_________ stm32comm _______", comm)
--		end
	end

	if(status == "OK") then 
		return value 
	else 
		return "ERROR" 
	end
end



function modem:notify(event_name, event_data)
	self.conn:notify(self.ubus_objects["tsmodem.driver"].__ubusobj, event_name, event_data )
end


local metatable = { 
	__call = function(table, ...)
--		print("__CALL")

		table:init_mk()
		table:make_ubus()

		uloop.init()

		local timer
		function t()
			modem:init()
			timer:set(modem.tick_size)
		end
		timer = uloop.timer(t)
		timer:set(modem.tick_size)


		uloop.run()
		table.conn:close()
		return table
	end
}
setmetatable(modem, metatable)
modem()