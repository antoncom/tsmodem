local cp2112 = require "gpio_cp2112_driver"
local parser_gpio = require"gpio_cp2112_parser"

print("**** CP2112 Hardware test RUN ****")
print("--------------------------------------------------------")

print("Set direction of [IO0.. IO1] LED-ports to output ...")
print("Set LED1, LED2 - ON")
cp2112:ConfigureOutGPIO(cp2112.IO0) 	-- D1 (IO0)
cp2112:ConfigureOutGPIO(cp2112.IO1) 	-- D2 (IO1)
os.execute("sleep 1")

print("Set LED1, LED2 - OFF")
cp2112:SetGPIO(cp2112.IO0)
cp2112:SetGPIO(cp2112.IO1)
os.execute("sleep 1")

print("--------------------------------------------------------")
print("Set direction of [IO5.. IO7] button-ports to input ...")
cp2112:ConfigureInGPIO_IRQ(cp2112.IO5, "rising") -- IO5
cp2112:ConfigureInGPIO_IRQ(cp2112.IO6, "rising") -- IO6
cp2112:ConfigureInGPIO_IRQ(cp2112.IO7, "rising") -- IO7
os.execute("sleep 1")

print("Read direction of [IO5.. IO7]:")
print("IO0 Dir: ".. cp2112:GetDirection(cp2112.IO0) .. ", Val: " .. cp2112:ReadGPIO(cp2112.IO0))
print("IO1 Dir: ".. cp2112:GetDirection(cp2112.IO1) .. ", Val: " .. cp2112:ReadGPIO(cp2112.IO1))
print("IO5 Dir: " .. cp2112:GetDirection(cp2112.IO5) .. ", Trg: " .. cp2112:GetEdge(cp2112.IO5))
print("IO6 Dir: " .. cp2112:GetDirection(cp2112.IO6) .. ", Trg: " .. cp2112:GetEdge(cp2112.IO6))
print("IO7 Dir: " .. cp2112:GetDirection(cp2112.IO7) .. ", Trg: " .. cp2112:GetEdge(cp2112.IO7))
os.execute("sleep 1")

print("--------------------------------------------------------")
print("Press any button-ports [IO5.. IO7]...")
os.execute("sleep 3")
print("IO5 IRQ Counter: " .. parser_gpio:ReadGPIO_IRQ(cp2112.IO5))
print("IO6 IRQ Counter: " .. parser_gpio:ReadGPIO_IRQ(cp2112.IO6))
print("IO7 IRQ Counter: " .. parser_gpio:ReadGPIO_IRQ(cp2112.IO7))
print("--------------------------------------------------------")
print("**** CP2112 Hardware test COMPLETED ****")