-- Главный модуль сервиса Tsmodem.
-- Инициализирует (связывает) модули сервиса (tsmodem.state, tsmodem.timer, tsmodem.notifier).
-- Опрашивает GSM-модем на логическом порту метолом poll, в ходе чего
-- запускает парсеры AT-ответов модема согласно спецификации /src/spec/*


local socket = require "socket"
local bit = require "bit"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "tsmodem.util.log"
local uloop = require "uloop"
local sys  = require "luci.sys"

local M = require 'posix.termio'
local F = require 'posix.fcntl'
local U = require 'posix.unistd'

local checkubus = require "tsmodem.util.checkubus"

-- Constants & utils
local AT_RELATED_UBUS_METHODS = require 'tsmodem.constants.AT_related_ubus_methods'

require "tsmodem.util.split_string"
require "tsmodem.driver.util"


-- AT Manual Specification related
local spec_V300_ch3 = require "tsmodem.spec.v300_ch3"
local spec_V300_ch4 = require "tsmodem.spec.v300_ch4"
local spec_V300_ch9 = require "tsmodem.spec.v300_ch9"

local def_events = require "tsmodem.constants.def_events"

local lock = require "tsmodem.driver.lock"

local modem = {}
modem.debug = (uci:get("tsmodem", "debug", "enable") == "1") and true
modem.debug_type = uci:get("tsmodem", "debug", "type")

modem.device = arg[1] or '/dev/ttyUSB1'         -- First port
modem.fds = nil                                 -- File descriptor for /dev/ttyUSB2
modem.fds_ev = nil      						-- Event loop descriptor
modem.ws_fds = nil								-- Websocket file descriptor
modem.ws_fds_ev = nil
modem.ws_pipeout_file = "/tmp/wspipeout.fifo"	-- Gwsocket creates it
modem.ws_pipein_file = "/tmp/wspipein.fifo" -- Gwsocket creates it
modem.defined_events = {}
modem.lock = lock
modem.tty_old_connected = "nil"
modem.cpin_ready_counter = 0
modem.slot_changed_recently = nil
modem.slot_reset_recently = nil

modem.last_iccid = nil
modem.crsm_buf = ""
modem.need_network_restart = false

-- [[ UCI staff ]]
modem.config = "tsmodem"
modem.config_gsm = "tsmodem_adapter_provider"
modem.section = "sim"


-- Функция начальной инициализации сервиса.
-- Запускается периодически по таймеру (см. в модуле timer.general)
-- Выполняется только при условии, что модем не подключен к файловому дескриптору.
function modem:init()
	
	if not self:is_connected(modem.fds) then

		modem:unpoll()

		if modem.fds then
			if_debug(modem.debug_type, "......")

			U.close(modem.fds)
			
			modem.state:update("usb", "disconnected", modem.device .. " close")
			modem.state:update("reg", "7", "AT+CREG?")
			modem.state:update("signal", "", "AT+CSQ")
			modem.state:update("cpin","", "","")
		end

		local fds, err, errnum = F.open(modem.device, bit.bor(F.O_RDWR, F.O_NONBLOCK))
		if fds then


			local term_attrs = M.tcsetattr(fds, 0, {
			   cflag = M.B115200 + M.CS8 + M.CLOCAL + M.CREAD,
			   iflag = M.IGNPAR,
			   oflag = M.OPOST,
			   cc = {
			      [M.VTIME] = 0,
			      [M.VMIN] = 1,
			   }
			})
			modem.fds = fds


			-- При запуске Tsmodem станвится busy до тех пор, пока не подключиться к порту /dev/ttyUSBx
			-- Как только подключился к порту - разлокируем для потребтелей
			local lock_res, lock_note = lock.unlock("tsmodem", true)

			if_debug(modem.debug_type,"┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
            if_debug(modem.debug_type,"┃ Modem connected to " .. tostring(modem.device) .." ┃")
            if_debug(modem.debug_type,"┃ Tsmodem lock: " .. tostring(lock_note) .."          ┃")
            if_debug(modem.debug_type,"┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")

			-- Принудительный перевод модема в режим Text
			U.write(modem.fds, "AT+CMGF=1\r\n")

			if_debug("send_at", "AT+CMGF=1 - I go to text-mode.")

			-- Удаление всех смс с сим-карты при первом старте Tsmodem
			U.write(modem.fds, "AT+CMGF=1;+CMGD=1,4" .. "\r\n")
		    if_debug("send_at", "AT SEND +CMGD: delete all SMS")
    		if_debug("send_at", "----------------------")

    			--
			local sim_id = modem.state:get("sim", "value")
			if (sim_id == "1" or sim_id == "0") then
                local provider_id = get_provider_id(sim_id)
				local apn_provider = uci:get(modem.config_gsm, provider_id, "gate_address") or "APNP"
				local apn_network = uci:get("network", "tsmodem", "apn") or "APNN"
				if(apn_provider ~= apn_network) then
					uci:set("network", "tsmodem", "apn", apn_provider)
					uci:save("network")
					uci:commit("network")
				end
			end

			modem.state:update("usb", "connected", modem.device .. " open", "")
			modem.state:update("reg", "7", "AT+CREG?", "")
			modem.state:update("signal", "", "AT+CSQ", "")
			modem.state:update("cpin","", "","")

		end
	end
end

function modem:is_connected(fd)
	local tty_connected = (fd and U.isatty(fd))
	if ((not tty_connected) and modem.tty_old_connected == "1") then 
		if_debug(modem.debug_type,"┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
        if_debug(modem.debug_type,"┃ Modem disconnected from " .. tostring(modem.device) .." ┃")
        if_debug(modem.debug_type,"┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")

        if_debug(modem.debug_type,"┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
        if_debug(modem.debug_type,'┃ Type "tsmslot debug" in a different shell ┃')
        if_debug(modem.debug_type,"┃ to see how to the slot resetting process  ┃")
        if_debug(modem.debug_type,"┃ is going on..                             ┃")
        if_debug(modem.debug_type,"┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
	end
	modem.tty_old_connected = tostring(tty_connected)
	return tty_connected

end

-- Функция запускает опрос модема (ожидает данные а файловом дескрипторе).
-- Выполняетя по таймеру (см. в модуле timer.general).
-- Если модем нештатно отключился от логического порта, то вначале выполняется .init() - см. выше
-- а затем проверяется был ли запущен опрос (polling). Если нет - запускает polling.

-- В процессе ожидания АТ-ответов от модема данная функция запускает парсинг.
modem.at_answer_buffer = ""
modem.at_answer_timer = nil

function modem:poll()

	if (modem.fds_ev == nil) and modem:is_connected(modem.fds) then
		modem.fds_ev = uloop.fd_add(modem.fds, function(ufd, events)

			local message_from_browser, message_to_browser = "", ""
			local chunk, err, errcode = U.read(modem.fds, 1024)

			if (err) then
				if_debug(modem.debug_type, "POLL err[" .. tostring(err) .. "]" .. chunk .. string.format("tsmodem: U.read(modem.fds, 1024) ERROR CODE: %s", tostring(errcode)))
			end

			if not err then

				if chunk:find("+CRSM") then

					if_debug(modem.debug_type, "AT-ANSWER +CRSM: " .. chunk:gsub("%c+", " "))

					-- вызывать на каждый пришедший кусок ответа на AT+CRSM
					-- возвращает: nil — ответ ещё неполный; true/false — карта сменилась/нет
					local function check_sim_changed(chunk)
					    modem.crsm_buf = modem.crsm_buf .. chunk

					    local finished = modem.crsm_buf:find("\r\nOK\r\n", 1, true)
					                  or modem.crsm_buf:find("ERROR", 1, true)
					    if not finished then
					        return nil                          -- ждём продолжения, ничего не решаем
					    end

					    local resp = modem.crsm_buf
					    modem.crsm_buf = ""

					    local sw1, data = resp:match('%+CRSM:%s*(%d+),%d+,"(%x+)"')
					    if sw1 ~= "144" or not data then
					        return true                         -- полный ответ, но карта не прочиталась
					    end
					    if last_iccid and data ~= last_iccid then
					        last_iccid = data
					        return true
					    end
					    last_iccid = data
					    return false
					end

					if not modem.slot_reset_recently then
						if check_sim_changed(chunk) then
							if_debug("", "SIM ICCID changed. AT+CFUN=0/1 run via Tsmslot reset ubus method..", "red")
							util.ubus("tsmslot", "reset", {})

							-- Также прекращаем Link до gsm-провайдера
							local t = uloop.timer(function()
								util.ubus("network.interface.modem", "down", {})
							end)
							t:set(1000)
						end
					end
				end

				-- Разбираем АТ-ответы от модема согласно спецификации
				
				spec_V300_ch3:parse_AT(modem, chunk)
				spec_V300_ch4:parse_AT(modem, chunk) -- balance via USSD, sim provider_id check
				spec_V300_ch9:parse_AT(modem, chunk)

				-- Если АТ-овет предназначен для стороннего сервиса (Tsmsms, Tsmatconsole и т.п.)
				-- то отправляем событие не сразу, а подождав 1 сек. пока возможные "хвосты"
				-- AT-ответа придут в переменую-буфер "modem.at_answer_buffer":

				if modem.lock.is_notify() then

					if modem.at_answer_timer == nil then
						modem.at_answer_timer = uloop.timer(function()
							if_debug("send_at", "AT-ANSWER IN 1 SEC", "yellow")
							local event_name = "AT-ANSWER"
							local payload = {
								answer = modem.at_answer_buffer,
							}
							if_debug("send_at", "AT-ANSWER RIGHT NOW", "white")
							modem.notifier:fire(event_name, payload)
							modem.at_answer_timer:cancel()
							modem.at_answer_timer = nil
							modem.at_answer_buffer = ""
						end)
						modem.at_answer_timer:set(1000)
					end

					modem.at_answer_buffer = modem.at_answer_buffer .. chunk


				end
			else
				if (modem.debug and (util.contains(AT_RELATED_UBUS_METHODS, modem.debug_type) or modem.debug_type == "all")) then
					if_debug(modem.debug_type, "FILE  POLL  ERROR " .. string.format("tsmodem: U.read(modem.fds, 1024) ERROR CODE: %s", tostring(errcode)))
				end
				modem.no_any_at_answer_diring_15_sec = true
			end
		end, uloop.ULOOP_READ)
	end
end


function modem:unpoll()
	if(modem.fds_ev) then
		modem.fds_ev:delete()
		modem.fds_ev = nil
	end
end

function modem:close()
	if(modem.fds) then
		U.close(modem.fds)
	end
end

-- [[ Initialize ]]
local metatable = {
	__call = function(modem, state, timer, notifier)
        modem.state = state
        modem.timer = timer
        modem.notifier = notifier

        modem.defined_events = def_events

		local self_lock = modem.lock.is_owner_or_set_if_unlocked("self")

        modem.state.init(modem, timer, notifier)
        modem.timer.init(modem, state, notifier)
        modem.notifier.init(modem, state, timer)

        modem.state:make_ubus()

		uloop.init()

		-- Инициализируем и включаем опрос модема на порту /dev/tty
		modem:init()
		modem:poll()
		
		-- Повторяем периодически инициализацию и опрос только в том случае если модем нештатно отключися от порта /dev/tty
		timer.general:set(timer.interval.general)

		-- Периодически послаем в модем различные АТ-команды
		-- для получения сотояния сотовой сети.

		timer.CPIN:set(timer.interval.cpin)
		timer.CREG:set(timer.interval.reg)
		timer.CSQ:set(timer.interval.signal)
		timer.COPS:set(timer.interval.provider)
		timer.CNSMOD:set(timer.interval.netmode)
		timer.SLOT:set(timer.interval.slotinfo)
		timer.SIM_CHANGED_IN_THE_SAME_SLOT:set(timer.interval.check_sim_changed_in_the_same_slot)


		local unlock_status
		unlock_status, self_lock = modem.lock.unlock("self")

		uloop.run()
		state.conn:close()

		return table
	end
}
setmetatable(modem, metatable)

return modem
