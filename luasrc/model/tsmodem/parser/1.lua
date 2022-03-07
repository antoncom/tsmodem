--local charset = require "luci.model.tsmodem.util.charset"
local charset = require "charset"

function ucs2_ascii(s)
	if not s then return "" end
	local str = tostring(s)
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
-- return ucs2_ascii

-- AT+CUSD=1,*100#,15
print(ucs2_ascii(string.sub("07919772009070F66000FF0008120160118472618C0500030B04020020043F043E00200434043E044104420443043F043D043E0439002004460435043D0435002004410020044204400435043C044F0020043A0430043C043504400430043C0438002C00200435043C043A043E043900200431043004420430044004350435043900200035003002", 55)))
