local gpio = require "driver.gpio"
local confgpio = require "driver.confgpio"
local state = require "driver.state"
local notifier = require "driver.notifier"
local timer = require "driver.timer"

gpio(confgpio, state, notifier, timer)