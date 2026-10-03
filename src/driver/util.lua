-- Вспомогательные функции

local uci = require "luci.model.uci".cursor()
local util = require "luci.util"

function get_provider_id(sim_id)
	local provider_id
	if (sim_id and (sim_id == "0" or sim_id == "1")) then
		provider_id = uci:get("tsmodem", "sim_" .. sim_id, "provider")
	end
	return provider_id or ""
end




if_debug = function(dtype, msg, ...)
	local is_debug = (uci:get("tsmodem", "debug", "enable") == "1")
	local debug_type =uci:get("tsmodem", "debug", "type")
	local val = ""

	local colors = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    bright_red = "\27[91m",
    bright_green = "\27[92m",
    bright_yellow = "\27[93m",
    bright_blue = "\27[94m",
    bright_magenta = "\27[95m",
    bright_cyan = "\27[96m",
    bright_white = "\27[97m"
	}

	local color = {...}

	if (is_debug and (debug_type == dtype or debug_type == "all" or dtype == "")) then
		if (msg and type(msg) == "table") then
			val = util.serialize_json(msg)
		elseif (msg and type(msg) == "string") then
			val = msg:gsub("%c", " ")
		else
			val = msg
		end
		local dt = os.date("*t")  
		local ms = string.match(tostring(os.clock()), "%d%.(%d+)")  
		local d = string.format("%d:%d:%d", dt.hour, dt.min, dt.sec)  

		local socket = require 'socket'  
		local now = socket.gettime()  
		local millis = math.floor((now % 1) * 100)  
		if(#color > 0 and #color[1] > 0 and colors[color[1]]) then
			print(tostring(colors[color[1]]) .. string.format('%s.%02d', d, millis) .. " [tsmodem]: " .. tostring(val))
			util.perror(tostring(colors[color[1]]) .. string.format('%s.%02d', d, millis) .. " [tsmodem]: " .. tostring(val))
		else
			print(colors["white"] .. string.format('%s.%02d', d, millis) .. " [tsmodem]: " .. tostring(val))
			--util.perror(colors["white"] .. string.format('%s.%02d', d, millis) .. " [tsmodem]: " .. tostring(val))
		end
	end
end

-- Разбивает длинный текст на куски, для отправки по смс
function split_message(text, max_length)
  local chunks = {}
  local start = 1
  local chunk_size = max_length

  while start <= #text do
    chunks[#chunks + 1] = string.sub(text, start, start + chunk_size - 1)
    start = start + chunk_size
  end

  return chunks
end


