--local sms_text = "AT+CMGR=1\n\n+CMGR: \"REC READ\",\"+79996661322\",\"\",\"24/02/26,09:47:47+12\"\nbash: applogic restart"
--local at = '+CMTI: "SM",2'

local parser_sms = {}

-- Парсер номера телефона приславшего смс.
function parser_sms:find_phone_number(text)
	local key = "+79"
	local length = 9
    local result = {}
    for i = 1, #text do
        if text:sub(i, i+#key-1) == key then
            result = key .. text:sub(i+#key, i+#key+length-1)
            return result
        end
    end
end

-- Парсер тела команды из смс.
function parser_sms:find_sms_text(text)
    local start_index = string.find(text, "bash:") + 6
    return text:sub(start_index, start_index+30)
end

-- Парсер АТ-команды, сообщающей о поступлении смс.
function parser_sms:find_new_sms_index(at_response)
	local key = '+CMTI: "SM",'
	key_len = string.len(key)
	start_index = string.find(at_response, key)
	if start_index then
		local sms_num = at_response:sub(start_index+key_len, 30)
		return tonumber(sms_num)
	end		
end

return parser_sms

-- Тест парсеров.
--print("Index SMS = " .. find_new_sms_index(at))
--print("Tel nummber = " .. find_phone_number(sms_text))
--print("Command = " .. find_sms_text(sms_text)) 

