local uci = require "luci.model.uci".cursor()

function get_provider_id(sim_id)
	local provider_id
	if (sim_id and (sim_id == "0" or sim_id == "1")) then
		provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	end
	return provider_id or ""
end
