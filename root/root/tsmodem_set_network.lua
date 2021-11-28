local uci = require "luci.model.uci".cursor()
local util = require "luci.util"


--[[ /etc/config/network ]]

local iface_tsmodem = {
    proto='3g',
    username='root',
    ipv6='auto',
    apn='internet.mts.ru',
    device='/dev/ttyUSB2',
    service='umts'
}

local section = uci:section("network", "interface", "tsmodem", iface_tsmodem)
if section == "tsmodem" then
    uci:save("network")
    uci:commit("network")
else
    print("ERROR: uci section 'tsmodem' was not ceated in the /etc/config/network.")
end

--[[ lan interface update ]]

uci:delete("network", "lan")

local iface_lan = {
    type='bridge',
    ifname='eth0.1',
    proto='static',
    ipaddr='192.168.1.1',
    netmask='255.255.255.0',
    ip6assign='60',
    gateway='192.168.1.111',
    dns='8.8.8.8'
}

local section = uci:section("network", "interface", "lan", iface_lan)
if section == "lan" then
    uci:save("network")
    uci:commit("network")
    util.perror("Updating 'lan' interface..")
    util.dumptable(iface_lan)
else
    print("ERROR: interface 'lan' was not updated in the /etc/config/network.")
end

--[[ /etc/config/firewall ]]

uci:foreach("firewall", "zone", function(section)
    if(section and section["name"] == "wan") then
        local network = uci:get_list("firewall", section[".name"], "network")
        util.perror("Adding firewall network..")
        if not util.contains(network, "tsmodem") then
            network[#network+1] = "tsmodem"
            util.dumptable(network)

            local ok = uci:set_list("firewall", section[".name"], "network", network)
            if ok then
                uci:save("firewall")
                uci:commit("firewall")
            else
                print('ERROR: uci:set_list("firewall", "network"')
            end

        else
            print("INFO: 'tsmodem' network already exists in the firewall zone.")
        end
    end
end)
