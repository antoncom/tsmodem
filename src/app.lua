local stm = require "tsmodem.driver.stm"
local timer = require "tsmodem.driver.timer"
local state = require "tsmodem.driver.state"
local modem = require "tsmodem.driver.modem"
--local console = require "tsmodem.driver.console"

modem(state, stm, timer)
