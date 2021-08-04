# Copyright 2017-2020 Dirk Brenken (dev@brenken.org)
# This is free software, licensed under the Apache License, Version 2.0

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI TechnoSkver RTR01
LUCI_DEPENDS:=+luci-compat
LUCI_DESCRIPTION:=Double SIM management for Skw92A with Sim7600 modem integration.
LUCI_PKGARCH:=all

PKG_VERSION:=1.1.0
PKG_LICENSE:=GPL-3.0-or-later

include /home/anton/lua_projects/SKW92A/MAKING_A_PACKAGE/openwrt-sdk-19.07.7-ramips-mt76x8_gcc-7.5.0_musl.Linux-x86_64/feeds/luci/luci.mk
# include ../../luci.mk

define Package/postinst
	#!/bin/sh
	/etc/init.d/tsmodem enable
	/etc/init.d/tsmodem start
endef

define Package/prerm
	#!/bin/sh
	/etc/init.d/tsmodem stop
	/etc/init.d/tsmodem disable
endef