local uci = require "luci.model.uci".cursor()
local util = require "luci.util"

function get_provider_id(sim_id)
	local provider_id
	if (sim_id and (sim_id == "0" or sim_id == "1")) then
		provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	end
	return provider_id or ""
end

--[[
	ubus_method 			- название метода ubus для tsmodem.driver
	protocol 				- UBUS, AT, PING, FILE, STM
	request_or_response 	- "ASK", "ANSWER", "NOTIFY" or "POLL"
	value 					- значение
	comment 				- подсказка
]]
function if_debug(ubus_method, protocol, request_or_response, value, comment)
	local is_debug = (uci:get("tsmodem", "debug", "enable") == "1") and true
	local debug_type =uci:get("tsmodem", "debug", "type")
	local val = ""

	if (is_debug and (debug_type == ubus_method or debug_type == "all" or ubus_method == "")) then
		if (value and type(value) == "table") then
			val = util.serialize_json(value)
		else
			val = value
		end
		print(protocol .. ":" .. ubus_method, request_or_response,"", val,"","","", comment)
	end
end
