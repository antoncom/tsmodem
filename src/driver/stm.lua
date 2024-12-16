local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"

require "tsmodem.driver.util"


local stm = {}
stm.device = "/dev/ttyS1"
stm.fds = nil

stm.modem = nil
stm.state = nil
stm.timer = nil

stm.init = function(modem, state, timer, notifier)
    stm.modem = modem
    stm.state = state
    stm.timer = timer
    stm.notifier = notifier
    stm:init_mk()

    return stm
end

function stm:init_mk()
    local status, sim_id = stm:command("~0:SIM.SEL=?")
    if (status == "OK" and (sim_id == "0" or sim_id == "1")) then
        stm.state:update("sim", tostring(sim_id), "~0:SIM.SEL=?")
    else
    	util.perror("[tsmodem.driver.stm.lua] init_mk() ERROR")
    end

    -- Включить индикацию на 3 светодиоде: питание/подогрев CPU
    stm:command("~0:LED.3=s0")
end

function stm:command(comm)
	local value, status = '',''
    local buf = util.ubus("tsmodem.stm", "send", { command = comm })
    if not buf then return 'ERROR', 'No [tsmodem.stm] object on the UBUS.' end

	local b = util.split(buf["answer"])

	if(b[#b] == '') then
		table.remove(b, #b)
	end

	status = b[#b]
	value = b[#b-1]

	if(status == "OK") then
		return status, value
	else
		return "ERROR", ""
	end
end

return stm
