--local charset = require "luci.model.tsmodem.util.charset"
local charset = require "charset"

function ucs2_ascii(str)
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
