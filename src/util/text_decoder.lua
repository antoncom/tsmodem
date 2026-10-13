-- Модуль преобразования текста в различные форматы

local text_decoder = {}

-- Convert a hex string (e.g., "0041") into a raw byte string (e.g., "\x00\x41")
local function fromhex(hex)
    return (hex:gsub('..', function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

-- Convert a single Unicode codepoint into UTF-8 bytes and add to the output
local function encode_utf8(codepoint, out)
    if codepoint < 0x80 then
        -- 1-byte UTF-8 encoding
        out[#out+1] = string.char(codepoint)
    elseif codepoint < 0x800 then
        -- 2-byte UTF-8 encoding
        out[#out+1] = string.char(0xC0 + math.floor(codepoint / 0x40))
        out[#out+1] = string.char(0x80 + (codepoint % 0x40))
    else
        -- 3-byte UTF-8 encoding
        out[#out+1] = string.char(0xE0 + math.floor(codepoint / 0x1000))
        out[#out+1] = string.char(0x80 + (math.floor(codepoint / 0x40) % 0x40))
        out[#out+1] = string.char(0x80 + (codepoint % 0x40))
    end
end

-- Convert a UTF-16BE byte string into a UTF-8 string
-- Supports both basic characters and special high-low code unit pairs for emojis and other symbols
function text_decoder.utf16be_to_utf8(packed_hex)
    local bytes = fromhex(packed_hex)
    local out = {}      -- List of UTF-8 bytes
    local i = 1         -- Current position in the byte string

    while i + 1 <= #bytes do
        -- Read two bytes and combine into a 16-bit code unit
        local first_byte = string.byte(bytes, i)
        local second_byte = string.byte(bytes, i + 1)
        local codeunit = first_byte * 256 + second_byte

        -- Check if it's the start of a high surrogate (used for emojis and symbols outside the BMP)
        if codeunit >= 0xD800 and codeunit <= 0xDBFF and i + 3 <= #bytes then
            -- Read the next 16-bit code unit (low surrogate)
            local next_first_byte = string.byte(bytes, i + 2)
            local next_second_byte = string.byte(bytes, i + 3)
            local next_codeunit = next_first_byte * 256 + next_second_byte

            -- If the second unit is in the low surrogate range, combine both to get the full codepoint
            if next_codeunit >= 0xDC00 and next_codeunit <= 0xDFFF then
                local unicode_codepoint = 0x10000 + ((codeunit - 0xD800) * 0x400) + (next_codeunit - 0xDC00)

                -- Convert to 4-byte UTF-8
                out[#out+1] = string.char(0xF0 + math.floor(unicode_codepoint / 0x40000))
                out[#out+1] = string.char(0x80 + (math.floor(unicode_codepoint / 0x1000) % 0x40))
                out[#out+1] = string.char(0x80 + (math.floor(unicode_codepoint / 0x40) % 0x40))
                out[#out+1] = string.char(0x80 + (unicode_codepoint % 0x40))

                i = i + 4  -- Move past both 16-bit units
            else
                -- If not a valid pair, treat the first as a normal character
                encode_utf8(codeunit, out)
                i = i + 2
            end
        else
            -- Regular 16-bit character in the Basic Multilingual Plane (BMP)
            encode_utf8(codeunit, out)
            i = i + 2
        end
    end

    return table.concat(out)
end

-- 8-bit данные: интерпретируем как Latin-1 и переводим в UTF-8
function text_decoder.latin1_to_utf8(hex)
    local out = {}
    for i = 1, #hex - 1, 2 do
        encode_utf8(tonumber(hex:sub(i, i + 1), 16), out)
    end
    return table.concat(out)
end

-- GSM 7-bit default alphabet (3GPP TS 23.038)
local gsm7bit_table = {
    [0] = '@', '£', '$', '¥', 'è', 'é', 'ù', 'ì', 'ò', 'Ç', '\n', 'Ø', 'ø', '\r', 'Å', 'å',
    'Δ', '_', 'Φ', 'Γ', 'Λ', 'Ω', 'Π', 'Ψ', 'Σ', 'Θ', 'Ξ', '', 'Æ', 'æ', 'ß', 'É',
    ' ', '!', '"', '#', '¤', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '<', '=', '>', '?',
    '¡', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Ä', 'Ö', 'Ñ', 'Ü', '§',
    '¿', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'ä', 'ö', 'ñ', 'ü', 'à'
}

-- Таблица расширения (после escape-символа 0x1B)
local gsm7bit_ext_table = {
    [0x0A] = '\f', [0x14] = '^', [0x28] = '{', [0x29] = '}', [0x2F] = '\\',
    [0x3C] = '[', [0x3D] = '~', [0x3E] = ']', [0x40] = '|', [0x65] = '€',
}

-- GSM 7-bit decoding function
--   packed_hex    — упакованные септеты в hex
--   septet_count  — сколько септетов декодировать (TP-UDL); nil = все, что поместились
--   skip_septets  — сколько септетов пропустить в начале (UDH + fill bits)
function text_decoder.gsm7bit_to_text(packed_hex, septet_count, skip_septets)
    local bytes = {}
    for i = 1, #packed_hex - 1, 2 do
        bytes[#bytes + 1] = tonumber(packed_hex:sub(i, i + 1), 16)
    end

    local max_septets = math.floor(#bytes * 8 / 7)
    if not septet_count or septet_count > max_septets then
        septet_count = max_septets
    end
    skip_septets = skip_septets or 0

    local result = {}
    local escape = false
    for i = skip_septets, septet_count - 1 do
        local bit_offset = i * 7
        local byte_idx = math.floor(bit_offset / 8) + 1
        local shift = bit_offset % 8
        local value = math.floor(bytes[byte_idx] / 2 ^ shift)
        if shift > 1 and bytes[byte_idx + 1] then
            value = value + bytes[byte_idx + 1] * 2 ^ (8 - shift)
        end
        value = value % 128

        if escape then
            result[#result + 1] = gsm7bit_ext_table[value] or ' '
            escape = false
        elseif value == 0x1B then
            escape = true
        else
            result[#result + 1] = gsm7bit_table[value] or '?'
        end
    end

    return table.concat(result)
end

return text_decoder
