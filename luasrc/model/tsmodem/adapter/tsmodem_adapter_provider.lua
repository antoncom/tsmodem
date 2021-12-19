local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
local log = require "luci.model.tsmodem.util.log"
---------------------------------------------------------
--------- Change these when create new adapter ----------
local adapter_config = "tsmodem_adapter_provider"
local adapter_section = "provider" -->>-- and all in the code
---------------------------------------------------------
---------------------------------------------------------
local adapter_jsname = adapter_config

local provider = {}
provider.loaded = {}
provider.id = nil

function provider:new(relay_id)
	local template = uci:get_all(adapter_config, "template")
	for _, k in pairs({".name", ".anonymous", ".type", ".index"}) do template[k] = nil end

	uci:section(adapter_config, adapter_section, relay_id, template)
	uci:commit(adapter_config)
	provider.loaded = template
	provider.id = relay_id

	return provider.loaded
end

function provider:list()
	local names = {}
	for id, gsm in pairs(provider.loaded_all) do
		local key, value = gsm[".name"], gsm["name"]
		names[key] = value
	end
	return names
end

function provider:get(optname)
	return provider.loaded[optname]
end


function provider:set(...)
	-- if obj provided as argument
	if(#arg == 1) then
		provider.loaded = arg[1]
	end

	local success = false
	if(provider.id) then
		--success = uci:get(adapter_config, provider.id) or log("Unable to uci:get()", {adapter.config, provider.id})
		for key, value in pairs(provider.loaded) do
			if(key == "hostport" and (#util.split(value, ":") >= 2)) then
				success = uci:set(adapter_config, provider.id, "address", util.split(value, ":")[1]) or log("Unable to uci:set() - ", {adapter_config, provider.id, "address", util.split(value, ":")[1]})
				success = uci:set(adapter_config, provider.id, "port", util.split(value, ":")[2]) or log("Unable to uci:set() - ", {adapter_config, provider.id, "port", util.split(value, ":")[2]})
			end
			success = uci:set(adapter_config, provider.id, key, value) or log("Unable to uci:set() - ", {adapter_config, provider.id, key, value})
		end
	else
		log("ERROR provider:set() - no provider.id provided", {provider})
	end
end

function provider:save()
	local success = uci:save(adapter_config)
	success = success or log("ERROR: " .. adapter_config .. "uci:save() error", provider.loaded)
end

function provider:commit()
	local success = uci:commit(adapter_config)
	success = success or log("ERROR: " .. adapter_config .. "uci:commit() error", provider.loaded)
end

function provider:delete()
	local success = uci:delete(adapter_config, provider.id) or log("Unable to uci:delete() adapter", adapter_config, provider.id)
	success = uci:save(adapter_config) or log("Unable to uci:save() config after deleting adapter", adapter_config)
	success = uci:commit(adapter_config) or log("Unable to uci:commit() config after deleting adapter", adapter_config)
	provider.table = nil
	provider.id = nil
end

function provider:getLabel()
	return adapter_section:upper()
end

function provider:getName()
	return adapter_jsname
end

function provider:render(optname, ...)
	local value = provider.loaded[optname]
	local rendered = {
		-- Render specific representation of uci option and define extra, non-uci options
		---------------------------------------------------------------------------------
		cssfile = function()
			local path = util.libpath() .. '/view/tsmodem/ui_adapter/' .. adapter_jsname .. '.css.htm'
			return fs.readfile(path)
		end,

		validator = function()
			local path = util.libpath() .. '/view/tsmodem/ui_adapter/' .. adapter_jsname .. '.valid.js.htm'
			return fs.readfile(path)
		end,

		widgetfile = function()
			local path = util.libpath() .. '/view/tsmodem/ui_adapter/' .. adapter_jsname .. '.js.htm'
			return fs.readfile(path)
		end,

		jsinit = function()
			return string.format("window.%s = new ui.%s(adapters)", adapter_jsname, adapter_jsname)
		end,

		jsrender = function()
			return  "window." .. adapter_jsname .. ".render()"
		end,

		getvalues = function()
			return  "window." .. adapter_jsname .. ".getValue()"
		end,

		getfields = function()
			return "window." .. adapter_jsname .. ".getFields()"
		end,

		-- All trivial options are rendered as is
		-----------------------------------------
		default = function(optname)
			return provider:get(optname)
		end
	}
	return rendered[optname] ~= nil and rendered[optname]() or rendered['default'](optname)
end

-- Make a Functable to load gsm provider with "provider(id)" style
local metatable = {
	__call = function(table, ...)

		-- if id provided, then load from uci or create with template
		-- if id not provided, then only create the object for methods using
		local id = arg[1] ~= nil and arg[1] or nil
		if(id) then
			table.id = id
			table.loaded = uci:get_all(adapter_config, id) or table:new(id)
		end

		-- Keep in the cache all list of GSM providers
		table.loaded_all = uci:get_all(adapter_config) or {}
		if(table.loaded_all["template"]) then
			table.loaded_all["template"] = nil
		end

		return table
	end
}
setmetatable(provider, metatable)


return(provider)
