local a = 1
local r = (a == 0) or (function()
	print("Not equal")
end)()
