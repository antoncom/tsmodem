-- Модуль парсит PDU формат полученной смс и возвращает таблицу с данными об смс
--
-- Поддерживается:
--   * SMS-DELIVER (входящие) и SMS-SUBMIT (исходящие, сохранённые на SIM; AT+CMGL=4 отдаёт и их)
--   * заголовок пользовательских данных (UDH, флаг UDHI = бит 6 первого октета):
--     заголовок пропускается при декодировании текста, а из него извлекаются
--     данные о склейке длинных SMS (IEI 0x00 — 8-битный ref, IEI 0x08 — 16-битный ref)
--   * кодировки GSM 7-bit (с учётом fill-bits после UDH), 8-bit, UCS2 — по битам DCS,
--     а не только по точным значениям "00"/"08"
--   * буквенно-цифровой отправитель (тип адреса D0) и любые другие типы адреса
--   * знак часового пояса в TP-SCTS

local text_decoder = require "tsmodem.util.text_decoder"
local pdu_decoder = {}

local function hexbyte(msg, p)
    return tonumber(msg:sub(p, p + 1), 16)
end

-- Номер в semi-octet представлении ("10F1" -> "01" + "1")
local function semi_octets_to_digits(hex, digits_count)
    local out = {}
    for i = 1, #hex, 2 do
        out[#out + 1] = hex:sub(i + 1, i + 1)
        out[#out + 1] = hex:sub(i, i)
    end
    local s = table.concat(out)
    if digits_count then
        s = s:sub(1, digits_count)
    end
    return (s:gsub("[Ff]$", ""))
end

-- Читает адрес (отправителя/получателя). Возвращает строку адреса и новую позицию
local function read_address(msg, p)
    local addr_len = hexbyte(msg, p)          -- количество полезных semi-octets
    local addr_type = msg:sub(p + 2, p + 3)
    p = p + 4
    local addr_bytes = math.ceil(addr_len / 2)
    local addr_hex = msg:sub(p, p + addr_bytes * 2 - 1)
    p = p + addr_bytes * 2

    local type_num = tonumber(addr_type, 16) or 0
    local ton = math.floor(type_num / 16) % 8  -- Type Of Number

    local number
    if ton == 5 then                           -- буквенно-цифровой (D0, 50 ...)
        local septets = math.floor(addr_len * 4 / 7)
        number = text_decoder.gsm7bit_to_text(addr_hex, septets)
    else
        number = semi_octets_to_digits(addr_hex, addr_len)
        if ton == 1 then                       -- международный (91)
            number = "+" .. number
        end
    end

    return number, addr_type, string.format("%02X", addr_len), p
end

-- Определяет алфавит по Data Coding Scheme (3GPP TS 23.038, раздел 4)
local function dcs_alphabet(dcs)
    local group = math.floor(dcs / 16)
    if group <= 7 then                         -- 00xx / 01xx: general data coding
        if math.floor(dcs / 32) % 2 == 1 then
            return "compressed"
        end
        local a = math.floor(dcs / 4) % 4
        if a == 0 then return "gsm7" elseif a == 1 then return "8bit" elseif a == 2 then return "ucs2" end
        return "gsm7"
    elseif group == 0xC or group == 0xD then   -- MWI, GSM 7-bit
        return "gsm7"
    elseif group == 0xE then                   -- MWI, UCS2
        return "ucs2"
    elseif group == 0xF then
        return (math.floor(dcs / 4) % 2 == 1) and "8bit" or "gsm7"
    end
    return "gsm7"
end

-- Разбирает UDH. Возвращает таблицу concat {ref, total, seq} или nil
local function parse_udh(udh_hex)
    local concat = nil
    local i = 1
    while i + 3 <= #udh_hex do
        local iei = tonumber(udh_hex:sub(i, i + 1), 16)
        local iel = tonumber(udh_hex:sub(i + 2, i + 3), 16)
        local data = udh_hex:sub(i + 4, i + 3 + iel * 2)
        if iei == 0x00 and iel == 3 then
            concat = {
                ref = tonumber(data:sub(1, 2), 16),
                total = tonumber(data:sub(3, 4), 16),
                seq = tonumber(data:sub(5, 6), 16),
            }
        elseif iei == 0x08 and iel == 4 then
            concat = {
                ref = tonumber(data:sub(1, 4), 16),
                total = tonumber(data:sub(5, 6), 16),
                seq = tonumber(data:sub(7, 8), 16),
            }
        end
        i = i + 4 + iel * 2
    end
    if concat and (not concat.total or concat.total == 0 or not concat.seq or concat.seq == 0) then
        concat = nil
    end
    return concat
end

-- Разбирает TP-SCTS (7 октетов, semi-octets)
local function parse_scts(scts_hex)
    local function sw(i) -- i-й октет (1..7) с переставленными полубайтами
        local b = scts_hex:sub(i * 2 - 1, i * 2)
        return b:sub(2, 2) .. b:sub(1, 1)
    end

    local date = {
        year = sw(1), month = sw(2), day = sw(3),
        hours = sw(4), minutes = sw(5), seconds = sw(6),
        time_zone = sw(7),     -- как и раньше: строка в четвертях часа (без знака)
    }

    -- Часовой пояс: десятки — в младшем полубайте исходного октета, бит 3 — знак
    local raw = scts_hex:sub(13, 14)
    local tens_nibble = tonumber(raw:sub(2, 2), 16) or 0
    local units = tonumber(raw:sub(1, 1), 16) or 0
    local negative = tens_nibble >= 8
    local quarters = (tens_nibble % 8) * 10 + units
    local tz_minutes = quarters * 15 * (negative and -1 or 1)
    date.time_zone = string.format("%d", quarters)
    date.tz_minutes = tz_minutes

    local abs_min = math.abs(tz_minutes)
    local tz_text = (negative and tz_minutes ~= 0 and "-" or "+") .. tostring(math.floor(abs_min / 60))
    if abs_min % 60 ~= 0 then
        tz_text = tz_text .. string.format(":%02d", abs_min % 60)
    end

    date.text = date.day .. '.' .. date.month .. '.' .. date.year .. ' ' ..
        date.hours .. ':' .. date.minutes .. ':' .. date.seconds .. ' GMT' .. tz_text
    return date
end

local function empty_date()
    return { text = "", year = "", month = "", day = "", hours = "", minutes = "", seconds = "", time_zone = "", tz_minutes = 0 }
end

local function parse_unsafe(msg)
    msg = msg:upper()
    local p = 1

    -- SMSC
    local smsc_length = msg:sub(p, p + 1)
    local smsc_len_num = tonumber(smsc_length, 16)
    p = p + 2
    local smsc_address_type = ""
    local service_center_number = ""
    if smsc_len_num > 0 then
        smsc_address_type = msg:sub(p, p + 1)
        local smsc_hex = msg:sub(p + 2, p + smsc_len_num * 2 - 1)
        service_center_number = semi_octets_to_digits(smsc_hex)
        if smsc_address_type == "91" then
            service_center_number = "+" .. service_center_number
        end
        p = p + smsc_len_num * 2
    end

    -- Первый октет TPDU
    local message_type = msg:sub(p, p + 1)
    local first_octet = tonumber(message_type, 16)
    p = p + 2
    local mti = first_octet % 4
    local udhi = math.floor(first_octet / 64) % 2 == 1

    local result = {
        smsc_length = smsc_length,
        smsc_address_type = smsc_address_type,
        service_center_number = service_center_number,
        message_type = message_type,
        udhi = udhi,
        date = empty_date(),
        sender_number = "",
        message_text = "",
    }

    if mti == 0 then
        result.pdu_kind = "deliver"
        local number, addr_type, addr_len
        number, addr_type, addr_len, p = read_address(msg, p)
        result.sender_number = number
        result.sender_address_type = addr_type
        result.sender_address_length = addr_len
    elseif mti == 1 then
        -- SMS-SUBMIT: TP-MR, TP-DA, TP-PID, TP-DCS, [TP-VP], TP-UDL, TP-UD
        result.pdu_kind = "submit"
        p = p + 2 -- TP-MR
        local number, addr_type, addr_len
        number, addr_type, addr_len, p = read_address(msg, p)
        result.sender_number = number          -- для исходящих это номер получателя
        result.recipient_number = number
        result.sender_address_type = addr_type
        result.sender_address_length = addr_len
    else
        -- SMS-STATUS-REPORT и прочее: текст не декодируем
        result.pdu_kind = (mti == 2) and "status_report" or "unknown"
        return result
    end

    result.protocol_identifier = msg:sub(p, p + 1)
    p = p + 2

    result.data_coding_scheme = msg:sub(p, p + 1)
    local dcs = tonumber(result.data_coding_scheme, 16)
    p = p + 2

    if mti == 0 then
        result.date = parse_scts(msg:sub(p, p + 13))
        p = p + 14
    else
        local vpf = math.floor(first_octet / 8) % 4
        if vpf == 2 then p = p + 2 elseif vpf == 1 or vpf == 3 then p = p + 14 end
    end

    result.user_data_length = msg:sub(p, p + 1)
    local udl = tonumber(result.user_data_length, 16)
    p = p + 2

    local ud_hex = msg:sub(p, #msg)
    local alphabet = dcs_alphabet(dcs)
    result.alphabet = alphabet

    local udh_octets = 0
    if udhi and #ud_hex >= 2 then
        local udhl = tonumber(ud_hex:sub(1, 2), 16)
        udh_octets = udhl + 1
        result.udh = ud_hex:sub(1, udh_octets * 2)
        result.concat = parse_udh(ud_hex:sub(3, udh_octets * 2))
    end

    if alphabet == "gsm7" then
        -- UDL в септетах; UDH выровнен по границе септета (fill bits)
        local skip_septets = math.ceil(udh_octets * 8 / 7)
        result.message_hex = ud_hex
        result.message_text = text_decoder.gsm7bit_to_text(ud_hex, udl, skip_septets)
    else
        -- UDL в октетах
        local body_hex = ud_hex:sub(udh_octets * 2 + 1, udl * 2)
        result.message_hex = body_hex
        if alphabet == "ucs2" then
            result.message_text = text_decoder.utf16be_to_utf8(body_hex)
        elseif alphabet == "8bit" then
            result.message_text = text_decoder.latin1_to_utf8(body_hex)
        end
    end

    return result
end

-- Возвращает таблицу с данными смс либо nil и текст ошибки, если PDU не удалось разобрать
function pdu_decoder.parse(msg)
    if type(msg) ~= "string" or #msg < 20 then
        return nil, "empty or too short PDU"
    end
    local ok, res = pcall(parse_unsafe, msg)
    if not ok then
        return nil, tostring(res)
    end
    return res
end

return pdu_decoder
