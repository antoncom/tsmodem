local modem_state = {
	stm = {
--[[	{
			command = "",
			value = "",					-- 0 / 1 / OK / ERROR
			time = "",
			unread = "true"
		}]]
	},
	reg = {
--[[	{
			command = "AT+CREG?",
			value = "",					-- 0 / 1 / 2 / 3 / 4 / 5 / 6 / 7
			time = tostring(os.time()),
			unread = "true"
		}]]
	},
	sim = {
    	{
    			command = "~0:SIM.SEL=?",
    			value = "1",					-- 0 / 1
    			time = "",
    			unread = "true"
    	},
    },
	signal = {
--[[	{
			command = "AT+CSQ",
			value = "",					-- 0..31
			time = "",
			unread = "true"
		}]]
	},
	balance = {
--[[	{
			command = "__TODO__",
			value = "",
			time = "",
			unread = "true"
		}]]
	},
	usb = {
--[[	{
			command = "", 				-- /dev/ttyUSB open  |  /dev/ttyUSB close
			value = "",					-- connected / disconnected
			time = "",
			unread = "true"
		}]]
	},
}

function modem_get_state(var, param)
	local value = ""
	local v, p = tostring(var), tostring(param)
	if modem_state[v] and (#modem_state[v] > 0) and modem_state[v][#modem_state[v]][p] then
		value = modem_state[v][#modem_state[v]][p]
		return true, "", value
	else
		return false, string.format("State Var '%s' or Param '%s' are not found in list of state vars.", v, p), value
	end

end

local ok, err, sim_id = modem_get_state("sim","value")

print(ok, err, sim_id)
