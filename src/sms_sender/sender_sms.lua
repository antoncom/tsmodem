-- Функция для отправки SMS
function SendSms(phone_number, sms_text)
  -- Создание таблиц с данными для отправки
  local data1 = {
    proto = "ubus",
    uuid = "",
    obj = "tsmodem.driver",
    method = "send_at",
    params = {
      command = "AT+CMGS=+" .. phone_number
    }
  }

  local data2 = {
    proto = "ubus",
    uuid = "",
    obj = "tsmodem.driver",
    method = "send_at",
    params = {
      command = sms_text
    }
  }

  --local ctrl_z_command = "'{"proto":"ubus","uuid":"","obj":"tsmodem.driver","method":"send_at","params":{"command":"\x1a"}}'>>/tmp/wspipeout.fifo"

  -- Преобразование таблиц в JSON-строки
  local json1 = require("cjson").encode(data1)
  local json2 = require("cjson").encode(data2)

  -- Отправка данных в файл FIFO
  local file = io.open("/tmp/wspipeout.fifo", "w")
  if file then
    file:write(json1 .. "\n")
    file:close()

    -- Задержка 1000 миллисекунд
    --os.execute("sleep 1")

    -- Отправка второго сообщения
    file = io.open("/tmp/wspipeout.fifo", "w")
    if file then
      file:write(json2 .. "\n")
      file:close()
    end
  end
  --os.execute("sleep 1")
  os.execute("./ctrl_z.sh")
end

-- Пример использования функции
local phone_number = "79170660867"
local sms_text = "test rtr-2: func send sms v3"

SendSms(phone_number, sms_text)
