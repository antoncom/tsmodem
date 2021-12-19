
# Copyright 2017-2020 Dirk Brenken (dev@brenken.org)
# This is free software, licensed under the Apache License, Version 2.0

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI TechnoSkver RTR01
LUCI_DEPENDS:=+openssh-sftp-server +luci-compat +luaposix +luabitop +lpeg +coreutils-sleep +libubox-lua +luasocket +coreutils-stty +comgt +kmod-usb-serial +kmod-usb-serial-option +kmod-usb-serial-wwan +usb-modeswitch +kmod-usb-core +luci-app-uhttpd +luci-proto-3g
LUCI_DESCRIPTION:=Double SIM management for Skw92A with Sim7600 modem integration.
LUCI_PKGARCH:=all

PKG_NAME:=tsmodem
PKG_VERSION:=1.5.6f
PKG_LICENSE:=GPL-3.0-or-later


define Package/$(PKG_NAME)/postinst
	#!/bin/sh
	sleep 1;

	uci set uhttpd.main.redirect_https='0'
	uci set luci.ccache.enable='0'
	uci commit luci

	/etc/init.d/uhttpd restart

	lua /root/tsmodem_set_network.lua
	/etc/init.d/network restart

	/etc/init.d/tsmodem enable
endef

define Package/$(PKG_NAME)/prerm
	#!/bin/sh
	/etc/init.d/tsmodem stop
	sleep 3;
	/etc/init.d/tsmodem disable
endef

include /home/anton/lua_projects/SKW92A/MAKING_A_PACKAGE/openwrt-sdk-19.07.7-ramips-mt76x8_gcc-7.5.0_musl.Linux-x86_64/feeds/luci/luci.mk
# include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
#$(eval $(call BuildPackage,$(PKG_NAME)))