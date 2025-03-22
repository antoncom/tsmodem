local cp2112 = require "tsmgpio.driver.gpio_cp2112_driver"
local cp2112_IRQ = require "tsmgpio.parser.gpio_cp2112_parser"

local configurator = {}

configurator.tsmgpio = nil
configurator.state = nil
configurator.notifier = nil

configurator.init = function(tsmgpio, state, notifier)
    configurator.tsmgpio = tsmgpio
    configurator.state = state
    configurator.notifier = notifier
    print("configurator.init() OK")
    return configurator
end

return configurator