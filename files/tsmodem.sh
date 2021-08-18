#!/bin/sh

INITFILE=/etc/init.d/tsmodem
SERVICE_PID_FILE=/var/run/tsmodem.pid
APP=$0
PAR1=$1
PAR2=$2

usage() {
    echo "Usage: $APP [ COMMAND [ OPTIONS ] ]"
    echo "Without any command Tsmodem will be runned in the foreground without debug mode"
    echo
    echo "Commands are:"
    echo "    start|stop|restart|reload     controlling the daemon"
    echo "    list                          show list of parameters with values"
    echo "    debug all|balance|reg         run in rules debug mode: use parameter name (balance, reg, etc.)"
    echo "    help                          show this and exit"
    doexit
}
callinit() {
    [ -x $INITFILE ] || {
        echo "No init file '$INITFILE'"
        return
    }
    exec $INITFILE $1
    RETVAL=$?
}
run() {
    uci set tsmodem.debug.enable='0'
    uci set tsmodem.debug.type='all'
    uci commit

    exec /usr/bin/lua /usr/lib/lua/luci/model/tsmodem/driver/modem.lua
    RETVAL=$?
}

list() {
    ubus -v list tsmodem.driver
    RETVAL=$?
}

debug() {
    [ -z $PAR2 ] && {
        echo "Use debug all|balance|reg to set debug mode"
        return
    }
    tsmodem stop
    uci set tsmodem.debug.enable='1'
    uci set tsmodem.debug.type=$PAR2
    uci commit

    exec /usr/bin/lua /usr/lib/lua/luci/model/tsmodem/driver/modem.lua
    RETVAL=$?
}

doexit() {
    exit $RETVAL
}

[ -n "$INCLUDE_ONLY" ] && return

CMD="$1"
[ -z $CMD ] && {
    run
    doexit
}
shift
# See how we were called.
case "$CMD" in
    start|stop|restart|reload)
        callinit $CMD
        ;;
    debug)
        debug
        ;;
    list)
        list
        ;;
    *help|*?)
        usage $0
        ;;
    *)
        RETVAL=1
        usage $0
        ;;
esac

doexit
