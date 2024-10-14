local util = require "luci.util"

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
  local chunk = text:find("UNREAD")
	-- Находим начало подстроки
	local comm
	local comm_chunk
	local chend = -1
	local chunks = util.split(text,",",4)

	comm_chunk = chunks[#chunks]
	chend = comm_chunk:find('OK') or -1
	if chend > 0 then chend = chend - 1 end
	comm = comm_chunk:sub(15,chend):gsub('%c','')
	
	return comm	


--[[	local start_pos, end_pos = text:find("bash: ")
	-- Находим конец подстроки 		
	local _, end_text_pos = text:find("\r\n", end_pos)
	if start_pos and end_text_pos then
		-- Извлекаем текст между "bash: " и "\r\n"
    	local extracted_text = text:sub(end_pos + 1, end_text_pos - 2) 
    	-- Выводим извлеченный текст
    	return extracted_text 
	else
    	return nil
	end--]]
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



--print(parser_sms:get_sms_text('  +CMGR: "REC UNREAD","+79030507175","","24/09/21,18:52:54+16"  ls -l /tmp\rOK'))