
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
local uloop = require "uloop"
local flist = require "luci.model.tsmodem.util.filelist"


local rules = {}
local rules_setting = {
	name = "Группа правил управления модемом",
	rules_list = {
		id = "rules_lst",
		source = {
			model = "tsmodem.rule",
			proto = "UBUS",
			command = "list"
		},
		target = {
			value = {},
			state = false
		}
	},
	tick_size_default = 2000
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
					rule_list["name"] = self.setting.name
					log("RULE_LIST", rule_list)
					--------------------------------
					self.conn:reply(req, rule_list);
				end, {id = ubus.INT32, msg = ubus.STRING }
			},
	    	-- You get notified when someone subscribes to a channel
			__subscriber_cb = function( subs )
				print("RULE - total subs: ", subs )
			end
		}
	}
	self.conn:add( ubus_object )
	self.ubus_object = ubus_object
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
	local rules = self.setting.rules_list.target.value
	local state = ''
	for name, rule in util.kspairs(rules) do
		state = rule()
	end
end

local metatable = { 
	__call = function(table)
		table.setting = rules_setting
		local tick = table.setting.tick_size_default

		table:make_ubus()
		table:make()

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