#!/bin/bash
if [ "`id -u`" != "0" ]; then
    echo "ERROR: This script must be run as root." 1>&2
    exit 1
fi

if [ ! -f "config" ]; then
    echo "Unable to source configuration settings." 1>&2
    exit 1
fi
. config

/etc/init.d/bitcoind status 1>/dev/null 2>/dev/null
if [ "$?" -eq 0 ]; then
    /etc/init.d/bitcoind stop
fi

echo "Disabling bitcoind autostart"
update-rc.d -f bitcoind remove >/dev/null

echo "Removing Daemon user: ${DAEMON_USER}"
deluser "${DAEMON_USER}" >/dev/null 2>/dev/null
rm -rf "/home/${DAEMON_USER}"

echo "Uninstalling init.d"
rm /etc/init.d/bitcoind

echo "Uninstalling bitcoin-cli"
rm /usr/bin/bitcoin-cli

echo "Removing version-file"
rm .version

