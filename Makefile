
# Copyright 2017-2020 Dirk Brenken (dev@brenken.org)
# This is free software, licensed under the Apache License, Version 2.0

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI TechnoSkver RTR01
LUCI_DEPENDS:=+luci-i18n-base-ru +luci-i18n-base-en +openssh-sftp-server +luci-compat +luaposix +luabitop +lpeg +coreutils-sleep +libubox-lua +luasocket +coreutils-stty +comgt +kmod-usb-serial +kmod-usb-serial-option +kmod-usb-serial-wwan +usb-modeswitch +kmod-usb-core +luci-app-uhttpd +luci-proto-3g
LUCI_DESCRIPTION:=Double SIM management for Skw92A with Sim7600 modem integration.
LUCI_PKGARCH:=all

PKG_NAME:=tsmodem
PKG_VERSION:=1.8.1
PKG_RELEASE:=20220327
PKG_LICENSE:=GPL-3.0-or-later

define Package/$(PKG_NAME)/postinst
#	#!/bin/sh
#	sleep 1;

#	uci set uhttpd.main.redirect_https='0'
#	uci set luci.ccache.enable='0'
#	uci set luci.main.mediaurlbase='/luci-static/tsmodem'

#	uci set system.@system[0].timezone='<+03>-3'
#	uci set system.@system[0].zonename='Europe/Volgograd'
#	uci set system.@system[0].hostname='BITCORD-001'

#	uci set luci.main.lang='ru'

#	uci set wireless.default_radio0.ssid='BITCORD-001'
#	uci set wireless.default_radio0.key='btCrd001'
	

#	uci commit

#	/etc/init.d/uhttpd restart

#	lua /root/tsmodem_set_network.lua
#	/etc/init.d/network restart

#	/etc/init.d/tsmodem enable

endef

define Package/$(PKG_NAME)/prerm
#	#!/bin/sh
#	/etc/init.d/tsmodem stop
#	sleep 3;
#	/etc/init.d/tsmodem disable
endef

include /home/anton/lua_projects/SKW92A/MAKING_A_PACKAGE/openwrt-sdk-19.07.7-ramips-mt76x8_gcc-7.5.0_musl.Linux-x86_64/feeds/luci/luci.mk
# include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
#$(eval $(call BuildPackage,$(PKG_NAME)))