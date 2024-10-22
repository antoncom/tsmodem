require ("gpio")

local uloop = require("uloop")
uloop.init()

-- Адресация
local cp2112_gpio = {}
cp2112_gpio[1] = 408
cp2112_gpio[2] = 409
cp2112_gpio[3] = 410
cp2112_gpio[4] = 411
cp2112_gpio[5] = 412
cp2112_gpio[6] = 413
cp2112_gpio[7] = 414
cp2112_gpio[8] = 415

-- Настройка выходов
configureOutGPIO(cp2112_gpio[1])
configureOutGPIO(cp2112_gpio[2])

-- Настройка входов
configureInGPIO(cp2112_gpio[5])
configureInGPIO(cp2112_gpio[6])
configureInGPIO(cp2112_gpio[7])

-- Хелпер для опроса состояния выхода
function input_state(input_num)
  local val = readGPIO(input_num)
  --print(val)
  if val.."" == '1' then
    return true
  end
  return false
end

local polling_time_ms = 1 
local timer
function t()
	if input_state(cp2112_gpio[5]) or input_state(cp2112_gpio[6]) or input_state(cp2112_gpio[7]) then
		writeGPIO(cp2112_gpio[1],1)
	else
		writeGPIO(cp2112_gpio[1],0)
	end
	timer:set(polling_time_ms)
end
timer = uloop.timer(t)
timer:set(polling_time_ms)

uloop.run()