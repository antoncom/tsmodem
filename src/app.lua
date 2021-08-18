local stm = require "tsmodem.driver.stm"
local timer = require "tsmodem.driver.timer"
local state = require "tsmodem.driver.state"
local modem = require "tsmodem.driver.modem"

modem(state, stm, timer)
