
# Copyright 2017-2020 Dirk Brenken (dev@brenken.org)
# This is free software, licensed under the Apache License, Version 2.0

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI TechnoSkver RTR01
LUCI_DEPENDS:=+luci-compat +luaposix +luabitop +lpeg +coreutils-sleep
LUCI_DESCRIPTION:=Double SIM management for Skw92A with Sim7600 modem integration.
LUCI_PKGARCH:=all

PKG_NAME:=ts_skw92a
PKG_VERSION:=1.3.0
PKG_LICENSE:=GPL-3.0-or-later


define Package/$(PKG_NAME)/postinst
	#!/bin/sh
	sleep 1;
	cd /usr/sbin
	tar -xf /root/ts_skw92a/gwsocket.tar
	/etc/init.d/tsmodem enable
	/etc/init.d/tsmodem start
endef

define Package/$(PKG_NAME)/prerm
	#!/bin/sh
	/etc/init.d/tsmodem stop
	sleep 3;
	/etc/init.d/tsmodem disable
	rm /usr/sbin/gwsocket
endef

include /home/anton/lua_projects/SKW92A/MAKING_A_PACKAGE/openwrt-sdk-19.07.7-ramips-mt76x8_gcc-7.5.0_musl.Linux-x86_64/feeds/luci/luci.mk
# include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
#$(eval $(call BuildPackage,$(PKG_NAME)))