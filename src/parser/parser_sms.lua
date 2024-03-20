local parser_sms = {}

-- Парсер номера телефона приславшего смс.
function parser_sms:get_phone_number(text)
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
function parser_sms:get_sms_text(text)
    local start_index = string.find(text, "bash:") + 6
    return text:sub(start_index, start_index+30)
end

-- Парсер АТ-команды, сообщающей о поступлении смс.
function parser_sms:get_sms_count(at_response)
	local key = '+CMTI: "SM",'
	local key_len = string.len(key)
	local start_index = string.find(at_response, key)
	if start_index then
		local sms_num = at_response:sub(start_index+key_len, start_index+key_len+2)
		return tonumber(sms_num)
		
	end		
end

function parser_sms:get_test_number()
	return 4
end

return parser_sms

