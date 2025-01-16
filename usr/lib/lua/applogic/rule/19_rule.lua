local debug_mode = require "applogic.debug_mode"
local rule_init = require "applogic.util.rule_init"
local log = require "applogic.util.log"

local rule = {}
local rule_setting = {
	title = {
		input = "Правило периодического опроса GPIO",
	},
	IO0 = {
		note = [[ Идентификатор GPIO линия 0 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},
	IO1 = {
		note = [[ Идентификатор GPIO линия 1 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO1",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},	
	IO2 = {
		note = [[ Идентификатор GPIO линия 0 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO2",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},	
	IO3 = {
		note = [[ Идентификатор GPIO линия 3 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},	
	IO4 = {
		note = [[ Идентификатор GPIO линия 4 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},
	IO5 = {
		note = [[ Идентификатор GPIO линия 5 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},	
	IO6 = {
		note = [[ Идентификатор GPIO линия 6 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},	
	IO7 = {
		note = [[ Идентификатор GPIO линия 7 ]],
		source = {
			type = "ubus",
			object = "tsmodem.gpio",
			method = "IO0",
			params = {},
		},
		modifier = {
			["1_bash"] = [[ jsonfilter -e $.value ]]
		}
	},				
}