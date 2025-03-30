local gpio = require "driver.gpio"
local confgpio = require "driver.confgpio"
local state = require "driver.state"

gpio(confgpio, state)