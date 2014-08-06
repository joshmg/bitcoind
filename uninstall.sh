#!/bin/bash
if [ "`id -u`" != "0" ]; then
    echo "ERROR: This script must be run as root." 1>&2
    exit 1
fi

DAEMON_USER='bitcoin'

deluser "${DAEMON_USER}"
rm -r "/home/${DAEMON_USER}"
rm /etc/init.d/bitcoind

