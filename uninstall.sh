#!/bin/bash
if [ "`id -u`" != "0" ]; then
    echo "ERROR: This script must be run as root." 1>&2
    exit 1
fi

DAEMON_USER='bitcoin'

/etc/init.d/bitcoind status 1>/dev/null 2>/dev/null
if [ "$?" -eq 0 ]; then
    /etc/init.d/bitcoind stop
fi

update-rc.d -f bitcoind remove
deluser "${DAEMON_USER}"
rm -r "/home/${DAEMON_USER}"
rm /etc/init.d/bitcoind
rm /usr/bin/bitcoin-cli

