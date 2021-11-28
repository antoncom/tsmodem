#!/bin/sh


cd /usr/lib/lua/luci/model/tsmodem/
echo "[tsmodem] Modem Lua-driver starting.."
lua driver.lua &

sleep 2;

echo "[tsmodem] Websocket daemon starting.."
/usr/sbin/gwsocket --ssl-cert=/root/ts_skw92a/server.pem --ssl-key=/root/ts_skw92a/server.key --port=7890 &

sleep 2;

cd /usr/lib/lua/luci/model/tsmodem/
echo "[tsmodem] Main Logic Rules starting.."
lua rules.lua &

echo "[tsmodem] Clear LuCI cache daemon starting.."
/root/clean_tmp_luci.sh &

echo "[tsmodem] Application started completely."
echo "----------------------------------------"

