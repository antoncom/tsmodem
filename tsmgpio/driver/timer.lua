local uloop = require "uloop"

local timer = {}

timer.interval_ms = {
	notify_ubus = 2000,
	check_gpio_event = 100,
	check_gpio_config = 300
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

function TimerCheckGPIO_Config()
	timer.confgpio:UpdateGPIO_InConfig()
	timer.check_gpio_config:set(timer.interval_ms.check_gpio_config)
end
timer.check_gpio_config = uloop.timer(TimerCheckGPIO_Config)

function timer:init(gpio, state, confgpio, notifier)
	timer.gpio = gpio
	timer.state = state
	timer.confgpio = confgpio
	timer.notifier = notifier
	TimerNotifyUbus()
	TimerCheckGPIO_Config()
	-- Эта функция перенесена в 09_rule
	--TimerCheckGPIO_Event()
	print("timer init OK")
end

return timer