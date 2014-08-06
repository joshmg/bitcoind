#!/bin/bash

if [ ! -f ~/.bitcoin/bitcoin.conf ]; then
    echo "ERROR: ~/.bitcoin/bitcoin.conf not found." 1>&2

    if [ "`id -u`" = "0" ]; then
        echo "NOTICE: This script DOES NOT need to be run as root." 1>&2
    fi

    exit 1
fi

connections=`bitcoin-cli getinfo | grep "connections" | sed 's/^.*:[^0-9]*\([0-9]\+\),$/\1/p' | tail -n1`

if [ "$?" -gt 0 ]; then
    echo "Unable to connect to bitcoind." 1>&2
    exit 1
fi

if [ "${connections}" -gt 8 ]; then
    echo "You're successfully contributing to the network. (${connections} Peers Connected)"
else
    echo "You're not contributing to the network (yet). Ensure your router is forwarding port 8333 and check again. (${connections} Peers Connected)"
fi
