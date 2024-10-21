local util = require "luci.util"
local ubus = require "ubus"
local uloop = require "uloop"
local sys  = require "luci.sys"


local F = require 'posix.fcntl'
local U = require 'posix.unistd'

local tsmconsole = {}
tsmconsole.session = ""								-- Ubus rpc session of that user who logged in the web UI.
tsmconsole.modal = ""								-- "opened" or "closed" are only possible
tsmconsole.conn = nil								-- Ubus connection
tsmconsole.fds = nil                                -- File descriptor
tsmconsole.fds_ev = nil                             -- Event loop descriptor
tsmconsole.pipeout_file = "/tmp/wspipeout.fifo"	    -- Gwsocket creates it
tsmconsole.pipein_file = "/tmp/wspipein.fifo"       -- Gwsocket creates it


function tsmconsole:init()
	if not tsmconsole.fds then
		tsmconsole.fds = F.open(tsmconsole.pipeout_file, F.O_RDONLY + F.O_NONBLOCK)
		tsmconsole.conn = ubus.connect()
		if not tsmconsole.conn then
			error("Failed to connect to ubus")
		end
	end
end

function tsmconsole:poll()
    if not tsmconsole.fds_ev then
        tsmconsole.fds_ev = uloop.fd_add(tsmconsole.fds, function(ufd, events)
            local message_from_browser, shell_command = "", ""
            local ubus_response = {}

            message_from_browser, err, errcode = U.read(tsmconsole.fds, 1024)

            if message_from_browser and (not err) then
				local web_browser_data = luci.jsonc.parse(message_from_browser)
				local driver_command = web_browser_data and web_browser_data["driver_command"] or nil

				if driver_command and driver_command == "driver-stop-automation" then
					ubus_response = util.ubus("tsmodem.driver", "automation", { ["mode"] = "stop" })
					tsmconsole.session = web_browser_data and web_browser_data["ubus_rpc_session"] or ""
					tsmconsole.modal = "opened"
				elseif driver_command and driver_command == "driver-start-automation" then
					ubus_response = util.ubus("tsmodem.driver", "automation", { ["mode"] = "run" })
					tsmconsole.session = ""
					tsmconsole.modal = "closed"
                else
					local at_command = web_browser_data and web_browser_data["AT_command"] or nil
					if at_command then
                    	ubus_response = util.ubus("tsmodem.driver", "send_at", { ["command"] = at_command })
					end
                end
            end

			if message_from_browser and (not err) then
				local ubus_response = {}
				local web_browser_data = luci.jsonc.parse(message_from_browser)
				local proto = web_browser_data and web_browser_data["proto"] or nil
				if proto and proto == "ubus" then
					local uuid = web_browser_data["uuid"]
					local obj = web_browser_data["obj"]
					local method = web_browser_data["method"]
					local params = web_browser_data["params"]
					ubus_response = util.ubus(obj, method, params) or {}
					ubus_response["uuid"] = uuid

					local shell_command = string.format("echo '%s' > %s", util.serialize_json(ubus_response), tsmconsole.pipein_file)
					sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
				end
			end

        end, uloop.ULOOP_READ)
    end
end

function tsmconsole:make_ubus()
	local ubus_methods = {
		["tsmodem.console"] = {
			session = {
				function(req, msg)
					-- if msg["modal"] == "opened" then
					-- 	tsmconsole.modal = "opened"
					-- 	ubus_response = util.ubus("tsmodem.driver", "automation", { ["mode"] = "stop" })
					-- elseif msg["modal"] == "closed" then
					-- 	tsmconsole.modal = "closed"
					-- 	ubus_response = util.ubus("tsmodem.driver", "automation", { ["mode"] = "run" })
					-- end
					local resp = {
						["ubus_rpc_session"] = tsmconsole.session,
						["modal"] = tsmconsole.modal
					}
					tsmconsole.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			send_sms = {
				function(req, msg)
					local resp = {
						["send_sms_resp"] = "Empty response",
					}
					if msg["phone_number"] then 
						-- Выполнить АТ-команду для отправки смс
						--util.ubus("tsmodem.driver", "send_at", {"command":"AT+CMGS=+79170660867"})
						resp["send_sms_resp"] = "SMS Send"
					end
					tsmconsole.conn:reply(req, resp);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
		}
	}
	tsmconsole.conn:add( ubus_methods )

end


function tsmconsole:subscribe_ubus()
	local sub = {
		notify = function(msg, name)
			--TODO
			-- получить ответ от BITCORD CONSOLE (fix the bug with 2 terminal JS instance)
			print(msg["resp"])
			print("TSMCONSOLE NOTIFY== 2 ==", util.serialize_json({ module = "tsmconsole", result = msg["answer"]}), name)
			if(name == "AT-ANSWER") then
				local shell_command = string.format("echo '%s' > %s", util.serialize_json({
					module = "tsmconsole",
					AT_answer = msg["answer"]
				}), tsmconsole.pipein_file)
				sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
			elseif(name == "SMS_send_result") then
				local shell_command = string.format("echo '%s' > %s", util.serialize_json({
					module = "tsmconsole",
					SMS_send_result = msg["resp"]
				}), tsmconsole.pipein_file)
				sys.process.exec({"/bin/sh", "-c", shell_command }, true, true, false)
			end
		end
	}
    tsmconsole.conn:subscribe("tsmodem.driver", sub)
end


tsmconsole:init()
uloop.init()
tsmconsole:make_ubus()
tsmconsole:subscribe_ubus()
tsmconsole:poll()
uloop.run()
