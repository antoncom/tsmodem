
require "os"
require "ubus"
local sys  = require "luci.sys"

local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local uloop = require "uloop"
local flist = require "luci.model.tsmodem.util.filelist"
local uci = require "luci.model.uci".cursor()

local bit = require "bit"

local F = require "posix.fcntl"
local U = require "posix.unistd"

local config = "msmodem"


local rules = {}
local rules_setting = {
	name = "Группа правил управления модемом",
	rules_list = {
		id = "rules_list",
		source = {
			model = "tsmodem.rule",
			proto = "UBUS",
			command = "list"
		},
		target = {
			value = {}
		},
	},
	run_once = {"10_rule"},
	tick_size_default = 800
}


function rules:make_ubus()
	self.conn = ubus.connect()
	if not self.conn then
		error("rules:make_ubus() - Failed to connect to ubus")
	end

	local ubus_object = {
		["tsmodem.rule"] = {
			list = {
				function(req, msg)
					local rule_list = {}
					-- TODO create a list of all rules, when the "group rules" functionality will be done
					rule_list = self.setting
					--log("RULE_LIST", rule_list)
					--------------------------------
					self.conn:reply(req, { rule_list = "0" })

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
			wspipein = {
				function(req, msg)

					sys.exec('echo "NEW Im here, in Lua!" > /tmp/wspipein.fifo')
					self.conn:reply(req, { websocket = "ok" })

				end, {id = ubus.INT32, msg = ubus.STRING }
			},
	    	-- You get notified when someone subscribes to a channel
			__subscriber_cb = function( subs )
				print("*************RULE - total subs: ", subs )
			end
		},
	}
	self.conn:add( ubus_object )
	self.ubus_object = ubus_object

end

function rules:init_websocket()
	local sys  = require "luci.sys"
	local fds_ws, err, errnum = F.open("/tmp/wspipeout.fifo", bit.bor(F.O_RDONLY, F.O_NONBLOCK))
	if not fds_ws then
		print('Could not open serial port ', err, ':', errnum)
		os.exit(1)
	end
	self.fds_ws = fds_ws
end

function rules:notify(event_name, event_data)
	self.conn:notify(self.ubus_objects["tsmodem.driver"].__ubusobj, event_name, { message = event_data })
end


function rules:poll()
	self.fds_ws_ev = uloop.fd_add(self.fds_ws, function(ufd, events)
		local chunk, err, errcode = U.read(self.fds_ws, 128)
	    if chunk and (chunk ~= "\n") and (#chunk > 0) then
			-- modem:notify("AT-protocol-data", chunk)
			print("CHUNK", chunk)
		elseif(err) then
			error(err) 
		end
	end, uloop.ULOOP_READ)
end


function rules:make()
	-- include all rule files from ./rules folder
	-- the rules are stored to setting.rules_list.target.value
	local rules_path = util.libpath() .. "/model/tsmodem/rule"
	local id, rules = '', self.setting.rules_list.target.value

	local files = flist({path = rules_path, grep = ".lua"})
	for i=1, #files do
		id = util.split(files[i], '.lua')[1]
		rules[id] = require("luci.model.tsmodem.rule." .. id)
	end	
end


function rules:run_all(varlink)
	-- run each rule
	--print("run all " .. self.setting.tick_size_default)
	local rules = self.setting.rules_list.target.value
	local state = ''

	for name, rule in util.kspairs(rules) do
		-- Initiate rule with link to the present (parent) module
		-- Then the rule can send notification on the ubus object of parent module
		state = rule(self)
	end
end

local metatable = { 
	__call = function(table)
		table.setting = rules_setting
		local tick = table.setting.tick_size_default

		--print("make_ubus() & make()  run: " .. os:clock())
		table:make_ubus()
		table:make()

		table:init_websocket()
		-- table:poll()
		
		-- looping
		uloop.init()

		local timer
		function t()
			table:run_all()
			timer:set(tick)
		end
		timer = uloop.timer(t)
		timer:set(tick)

		uloop.run()

		table.conn:close()
		return table
	end
}
setmetatable(rules, metatable)
rules()