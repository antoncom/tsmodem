local cp2112 = require "gpio"
local parser_gpio = require("utils.parser_gpio")

print("**** CP2112 Hardware test RUN ****")
print("-----------------------------------")

cp2112:ConfigureOutGPIO(408) 	-- D1 (IO0)
cp2112:ConfigureOutGPIO(409) 	-- D2 (IO1)
cp2112:ConfigureInGPIO_IRQ(413, "rising") -- IO5
cp2112:ConfigureInGPIO_IRQ(414, "rising") -- IO6
cp2112:ConfigureInGPIO_IRQ(415, "rising") -- IO7

cp2112:WriteGPIO(0, 408) -- D1 ON
cp2112:WriteGPIO(0, 409) -- D2 ON

print("Init status:")
print("IO0 Dir: ".. cp2112:GetDirection(408))
print("IO1 Dir: ".. cp2112:GetDirection(409))
print("IO5 Dir:" .. cp2112:GetDirection(413) .. ", Trg: " .. cp2112:GetEdge(413))
print("IO6 Dir:" .. cp2112:GetDirection(414) .. ", Trg: " .. cp2112:GetEdge(414))
print("IO7 Dir:" .. cp2112:GetDirection(415) .. ", Trg: " .. cp2112:GetEdge(415))

print("-----------------------------------")
print("IO5 IRQ Counter: " .. parser_gpio:ParserGPIO_IRQ(5))
print("IO6 IRQ Counter: " .. parser_gpio:ParserGPIO_IRQ(6))
print("IO7 IRQ Counter: " .. parser_gpio:ParserGPIO_IRQ(7))