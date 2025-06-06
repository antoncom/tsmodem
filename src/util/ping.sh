#!/bin/sh

ping_host() {
    host=$1
    #host=mmm.com
    sim_id=$2
    result=$(ping $host -c1 -A -w3 -W3 -q 2>/dev/null | awk -v HOST="$host" '{
        if(NF>6) {
            loss = $7; loss = substr($7, 0, length($7)-1);
            if(loss == "100") {
                print "0"
            } else {
                print "1"
            }
        }
    }')

    # If ping responds with any error then it's the same like host unreachable
    if [[ -z "$result" ]]; then
       result=0
    fi

    ubus call tsmodem.driver ping_update '{"sim_id":"'$sim_id'","host":"'$host'","value":"'$result'"}' &> /dev/null

}

ping_list() {
    list=$(echo "$1" | awk -F';' '{ for (i = 0; ++i <= NR;) print $i }')
    i=0
    for host in $list; do
        ping_host $host
        i=$((i+1))
    done
}

APP=$0
CMD=$1; shift
usage() {
    echo "Usage: $APP COMMAND [ OPTIONS ]"
    echo
    echo "Commands are:"
    echo "  --host        ping a host, return 0 or 1"
    echo "  --host-list   ping list of hosts; put ';' as delimiter"
    echo "  help          show this and exit"
}

case "$CMD" in
    help|-h|--help)
        usage
        exit 0
        ;;
    --host-list)
        ping_list $1
        ;;
    --host)
        ping_host $1 $2
        ;;
    *)
        usage $APP
        exit 1
        ;;
esac
