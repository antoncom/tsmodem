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
        RETVAL=1
        return
    }
    $INITFILE $1
    RETVAL=$?
}

is_running() {
    ubus call service list "{\"name\":\"$1\"}" 2>/dev/null | grep -q '"running": true'
}

restart_dependents() {
    i=0
    while [ $i -lt 60 ]; do
        ubus list tsmodem.driver >/dev/null 2>&1 && break
        sleep 1
        i=$((i+1))
    done
    for s in applogic tsmatconsole tsmsms tsmsmsconsole; do
        is_running $s && /etc/init.d/$s restart
    done
}

run() {
    uci set tsmodem.debug.enable='0'
    uci set tsmodem.debug.type='all'
    uci commit tsmodem

    /usr/bin/lua /usr/lib/lua/tsmodem/app.lua &
    LUA_PID=$!
    trap 'kill $LUA_PID 2>/dev/null' INT TERM EXIT

    restart_dependents >/dev/null 2>&1 &

    wait $LUA_PID
    RETVAL=$?
    logger -t tsmodem-wrap "app.lua exited, rc=$RETVAL"
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
    uci commit tsmodem

    exec /usr/bin/lua /usr/lib/lua/tsmodem/app.lua

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
    start|restart|reload)
        callinit $CMD
        ;;
    debug)
        debug
        ;;
    list)
        list
        ;;
    stop)
        callinit $CMD
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
