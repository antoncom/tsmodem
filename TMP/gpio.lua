--@author: Ewelina, Rafa, Rafa
-- Link: https://github.com/rsisto/luaGpio/blob/master/outputTest.lua
-- modifier: aos

-- Адресация пинов GPIO
local cp2112_gpio = {}
-- Создаем таблицу для перевода имен в индексы для чипа cp2112
local gpio_names = {
  IO0 = 1, -- D1 Led
  IO1 = 2, -- D2 Led
  IO2 = 3,
  IO3 = 4,
  IO4 = 5,
  IO5 = 6,
  IO6 = 7,
  IO7 = 8,
}
-- Заполняем таблицу cp2112_gpio с помощью имен
for name, index in pairs(gpio_names) do
  cp2112_gpio[name] = 407 + index
end

--Утилиты GPIO  
--Записывает 'что' в 'куда'
function writeToFile (where,what)
	local fileToWrite=io.open(where, 'w')
	fileToWrite:write(what)
	fileToWrite:close()	
end
--Читает символ из файла 'где' и возвращает строку
function readFromFile (where)
	local fileToRead=io.open(where, 'r')
	fileStr = fileToRead:read(1)
	fileToRead:close()	
	return fileStr
end

--Возвращает true, если файл существует 
function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

--Экспортирует ID GPIO для использования в качестве выходного пина
function ConfigureOutGPIO (id)
	if not file_exists('/sys/class/gpio/gpio'..id..'/direction') then
		writeToFile('/sys/class/gpio/export',id)
	end
	writeToFile('/sys/class/gpio/gpio'..id..'/direction','out')
end

--Экспортирует ID GPIO для использования в качестве входного пина 
function configureInGPIO (id)
	if not file_exists('/sys/class/gpio/gpio'..id..'/direction') then
		writeToFile('/sys/class/gpio/export',id)
	end
	writeToFile('/sys/class/gpio/gpio'..id..'/direction','in')
end

--Экспортирует ID GPIO для использования в качестве входного пина 
-- с задействованием прерывания:
-- "none"    — отключить прерывание
-- "rising"  — включить прерывание по нисходящему фронту
-- "falling" — включить прерывание по восодящему фронту
-- "both"    — включить прерывание по обеим фронтам
function ConfigureInGPIO_IRQ (id, edge)
  if not file_exists('/sys/class/gpio/gpio'..id..'/direction') then
    writeToFile('/sys/class/gpio/export',id)
  end
  writeToFile('/sys/class/gpio/gpio'..id..'/direction','in')

  -- Проверка аргумента 'edge'
  if edge == nil or edge == 'none' or edge == 'rising' or edge == 'falling' or edge == 'both' then
    if edge == 'rising' then
      writeToFile('/sys/class/gpio/gpio'..id..'/edge', 'rising')
    elseif edge == 'falling' then
      writeToFile('/sys/class/gpio/gpio'..id..'/edge', 'falling')
    elseif edge == 'both' then
      writeToFile('/sys/class/gpio/gpio'..id..'/edge', 'both')
    end
  else
    -- Если аргумент задан неверно, устанавливаем режим по умолчанию 'none'
    writeToFile('/sys/class/gpio/gpio'..id..'/edge', 'none')
  end
end

--Читает GPIO 'id' и возвращает его значение  
--@Предварительное условие: GPIO 'id' должен быть экспортирован с помощью configureInGPIO  
function ReadGPIO(id)
	gpioVal = readFromFile('/sys/class/gpio/gpio'..id..'/value')
	return gpioVal
end

-- Возвращает счетчик прерываний выбранного пина
-- Прерывание срабатывает по условию(rising/falling/both)
local function ReadGPIO_IRQ(id)
  local IO = id - 408
  local counter_irq
  -- Выполняем bash-команду и перехватываем вывод
  local command_sh = "cat /proc/interrupts  | grep cp2112-gpio | grep "
  -- Фильтр для выбранного номера пина
  command_sh = command_sh .. tostring(IO)
  local handle = io.popen(command_sh)
  local output_sh = handle:read("*a")
  handle:close()
  counter_irq = tonumber(string.match(output_sh, ": +(%d+)"))
  return counter_irq
end

--Записывает значение в GPIO 'id'  
--@Предварительное условие: GPIO 'id' должен быть экспортирован с помощью configureOutGPIO
function WriteGPIO(id, val)
	-- Защита от некоректных аргументов
	if val > 1 then val = 1 end
	if val < 0 then val = 0 end
	gpioVal = writeToFile('/sys/class/gpio/gpio'..id..'/value', val)
end

function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

return cp2112_gpio