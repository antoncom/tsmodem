local gpio = require "driver.gpio"
local confgpio = require "driver.confgpio"
local state = require "driver.state"
local notifier = require "driver.notifier"

gpio(confgpio, state, notifier)