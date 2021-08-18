#!/bin/sh


cd /usr/lib/lua/luci/model/tsmodem/
echo "[tsmodem] Modem Lua-driver starting.."
lua driver.lua &

sleep 2;

echo "[tsmodem] Websocket daemon starting.."
/usr/sbin/gwsocket &

sleep 2;

cd /usr/lib/lua/luci/model/tsmodem/
echo "[tsmodem] Main Logic Rules starting.."
lua rules.lua &

echo "[tsmodem] Application started completely."
echo "----------------------------------------"

