local confgpio = {}

confgpio.gpio = nil
confgpio.state = nil

function confgpio:init(gpio, state)
    confgpio.gpio = gpio
    confgpio.state = state
    
    print("confgpio.init() OK")
	return confgpio
end

return confgpio
