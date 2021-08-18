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

		if k == 1025 then
			k = 168 --Ё
		elseif k == 1105 then
			k = 184 --ё
		end

		if k > 1025 then
			result = charset[x] and (result .. charset[x]) or ""
		else
			result = result .. string.char(k)
		end
	end
    return result
end
return ucs2_ascii

-- AT+CUSD=1,*100#,15
--print(ucs2_ascii("003200320033002e0039003100200440002e000a041c0435043b043e04340438044f002000ab041404300432043004390020043d043500200431043e043b0435043900bb0020043e04420020004100640061006d0020043d04300020043304430434043e043a0020043704300020003800200440002f0434003a0020002a0037003707"))
