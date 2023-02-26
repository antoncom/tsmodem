local socket = require "socket"
local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

require "tsmodem.driver.util"


local stm = {}
stm.device = "/dev/ttyS1"
stm.fds = nil

stm.modem = nil
stm.state = nil
stm.timer = nil

stm.init = function(modem, state, timer)
    stm.modem = modem
    stm.state = state
    stm.timer = timer
    stm:init_mk()

    return stm
end

function stm:init_mk()
	local sys  = require "luci.sys"
    local initcom = string.format("stty -F %s 1000000", stm.device)
	sys.exec(initcom)
	socket.sleep(0.5)
	local fds_mk, err, errnum = F.open(stm.device, bit.bor(F.O_RDWR, F.O_NONBLOCK))
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
	stm.fds = fds_mk

	local res, sim_id = stm:command("~0:SIM.SEL=?")
	if res == "OK" then
		stm.state:update("sim", tostring(sim_id), "~0:SIM.SEL=?")
	else
		-- TODO: log error
	end
end

function stm:command(comm)
	local buf, value, status = '','',''

	U.write(stm.fds, comm .. "\r\n")
	socket.sleep(0.1)
	buf = U.read(stm.fds, 1024) or error('ERROR: no stm32 buf')

	local b = util.split(buf)
	if(b[#b] == '') then
		table.remove(b, #b)
	end

	status = b[#b]
	value = b[1]

	if(status == "OK") then
		return status, value
	else
		return "ERROR", ""
	end
end

-- [[ Initialize ]]
-- local metatable = {
-- 	__call = function(stm, modem, state)
--         stm.modem = modem
--         stm.state = state
--
-- 		return stm
-- 	end
-- }
-- setmetatable(stm, metatable)

return stm
