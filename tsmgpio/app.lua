local tsmgpio = require "tsmgpio.driver.tsmgpio"
local state = require "tsmgpio.driver.state"
local notifier = require "tsmgpio.driver.notifier"
local configurator = require "tsmgpio.driver.configurator"

tsmgpio(state, notifier, configurator)