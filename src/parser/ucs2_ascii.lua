local charset = require "tsmodem.util.charset"
--local charset = require "charset"

function ucs2_ascii(s)
	if not s then return "" end
	local str = tostring(s)
	if str == "" then return "" end

	local result, k, x = "", 0, 0
	for i=1, #str, 4 do
		x = string.upper(string.sub(str,i,i+3))
		k = tonumber(string.sub(str,i,i+3), 16)

		if k and k == 1025 then
			k = 168 --Ё
		elseif k and k == 1105 then
			k = 184 --ё
		end

		if k and k > 1025 then
			result = charset[x] and (result .. charset[x]) or ""
		else
			result = result .. string.char(k)
		end
	end
    return result
end
return ucs2_ascii

-- AT+CUSD=1,*100#,15
--print(ucs2_ascii("003600310031002e0032003000200440002e"))
