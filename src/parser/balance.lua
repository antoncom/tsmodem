local lpeg = require "lpeg"

function comma_to_point(s)
	local r = s:gsub(",", ".")
	return r
end

function balance(text)
	local spc = lpeg.S(" \t\n\r")^0
	local balance_masks = {
		" Vash balans __RUB__ r.", -- Beeline
	}

	for _, balance_mask in ipairs(balance_masks) do
		local n_RUB = balance_mask:find("__RUB__")
		local first_chunk = n_RUB and balance_mask:sub(1, n_RUB - 1) or ""
		first_chunk = first_chunk:match("^%s*(.*)") or first_chunk

		local balance_value = spc * lpeg.P(first_chunk) * spc *
			lpeg.C(
				lpeg.P('-')^-1 *
				lpeg.R('09')^1 *
				(
					lpeg.S('.,')^-1 *
					lpeg.R('09')^0
				)^-1
			) / comma_to_point / tonumber

		local result = balance_value:match(text)
		if result and type(result) == "number" then
			return result
		end
	end
end

return balance



-- [[ For local testing ]]

-- [[ MTS ]]
-- local text = [[+CUSD: 2,"Balance:633,100r"]]
-- print(text)
-- print(balance(1):match(text))

-- [[ BEELINE ]]
--local text = [[ Vash balanc 510.20 r. Slushajte 200 radiostantsij s bilajnom 1 den\' besplatno! Podkl: *279#]]
-- local text = [[510.20 р.]]

-- local text = [[ Vash balans 500.00 r.
-- Chitajte knigi vsej sem'yoj 7 dnej za 0 rub, dalee 20 r/den' *440# ]]

-- print(text)
-- print(balance(text))

