local uloop = require "uloop"

local timer = {}

timer.interval_ms = {
	notify_ubus = 2000,
	check_gpio_event = 100
}

function TimerNotifyUbus()
	timer.notifier:Run()
	timer.notify_ubus:set(timer.interval_ms.notify_ubus)
end
timer.notify_ubus = uloop.timer(TimerNotifyUbus)

function TimerCheckGPIO_Event()
	timer.gpio:ActionOnEvent()
	timer.check_gpio_event:set(timer.interval_ms.check_gpio_event)
end
timer.check_gpio_event = uloop.timer(TimerCheckGPIO_Event)

function timer:init(gpio, state, confgpio, notifier)
	timer.gpio = gpio
	timer.state = state
	timer.confgpio = confgpio
	timer.notifier = notifier
	print("timer init OK")
	TimerNotifyUbus()
	--TimerCheckGPIO_Event()
end

return timer