SHELL := /bin/bash

VM ?= openwrt.vm
DST ?= /root/ts_luci_skw92a/

install:
	@echo "== Install ts_luci_skw92a"
	@cp -fR luasrc/* /usr/lib/lua/
	@cp -fR www/* /www/
	@cp -fR root/etc/* /etc/
	@/etc/init.d/uhttpd restart

deploy:
	@echo "== Deploy project to VM"
	@rsync -avP . $(VM):$(DST) > /dev/null
	@ssh $(VM) "cd $(DST) && make install"
