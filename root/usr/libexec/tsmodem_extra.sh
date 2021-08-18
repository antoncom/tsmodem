#!/bin/sh

function ProgressBar {
# Process data
    let _progress=${1}*100/${2}*100/100
    let _done=${_progress}*4/10
    let _left=40-$_done
# Build progressbar string lengths
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:                           
# 1.2.1.1 Progress : [########################################] 100%
printf "\r[tsmodem] Reconnecting to /dev/ttyUSB2 : [${_fill// /#}${_empty// /-}] ${_progress}%%"

}

# Variables
_start=1

# This accounts as the "totalState" variable for the ProgressBar function
_end=20


## MAIN ACTION ##

echo "---------------------------------------------"
echo "[tsmodem] Stop service 'tsmodem' if running.."
/etc/init.d/tsmodem stop

stty -F /dev/ttyS1 1000000

# Parse DMESG to be sure ttyUSB2 is used for modem

_disconnectedRaw=`dmesg | grep -n "converter now disconnected from ttyUSB2$"  | cut -d : -f 1 | tail -1`
_notUSB2raw=`dmesg | grep -n "converter now attached to ttyUSB[^2]$"  | cut -d : -f 1 | tail -1`
_USB2raw=`dmesg | grep -n "converter now attached to ttyUSB2$"  | cut -d : -f 1 | tail -1`

if [[ $_USB2raw -lt $_disconnectedRaw  || $_USB2raw -lt $_notUSB2raw ]]; then


		# If not ttyUSB2 then reset modem and wait reconnection

		echo "~0:SIM.RST=0" > /dev/ttyS1
		sleep 1
		echo "~0:SIM.RST=1" > /dev/ttyS1

		for number in $(seq ${_start} ${_end})
		do
		    sleep 0.5
		    ProgressBar ${number} ${_end}

		    _disconnectedRaw=`dmesg | grep -n "converter now disconnected from ttyUSB2$"  | cut -d : -f 1 | tail -1`
		    _notUSB2raw=`dmesg | grep -n "converter now attached to ttyUSB[^2]$"  | cut -d : -f 1 | tail -1`
		    _USB2raw=`dmesg | grep -n "converter now attached to ttyUSB2$"  | cut -d : -f 1 | tail -1`

		    if [ $_USB2raw -gt $_disconnectedRaw ]; then
		    	if [ $_USB2raw -gt $_notUSB2raw ]; then

		    		# If ttyUSB2 reconnected - show 100% progress bar end exit loop

		    		ProgressBar $_end $_end
		    		break
		    	fi
			fi
		done


fi


echo ""
echo "[tsmodem] Modem has already been reconnected to /dev/ttyUSB2. Check it if needed."

cd /usr/lib/lua/luci/model/tsmodem/
echo "[tsmodem] Modem Lua-driver starting.."
lua driver.lua &

echo "[tsmodem] Websocket daemon starting.."
/usr/sbin/gwsocket &

sleep 2;

cd /usr/lib/lua/luci/model/tsmodem/
echo "[tsmodem] Main Logic Rules starting.."
lua rules.lua &

echo "[tsmodem] Application started completely."
echo "----------------------------------------"

