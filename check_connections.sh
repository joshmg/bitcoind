#!/bin/bash

if [ ! -f ~/.bitcoin/bitcoin.conf ]; then
    echo "ERROR: ~/.bitcoin/bitcoin.conf not found." 1>&2

    if [ "`id -u`" = "0" ]; then
        echo "NOTICE: This script DOES NOT need to be run as root." 1>&2
    fi

    exit 1
fi

# Test connection to bitcoind
tmp=`bitcoin-cli getinfo 2>/dev/null`
if [ "$?" -gt 0 ]; then
    echo "ERROR: Unable to connect to bitcoind." 1>&2
    exit 1
fi

connections=`bitcoin-cli getinfo | grep "connections" | sed 's/^.*:[^0-9]*\([0-9]\+\),$/\1/p' | tail -n1`

inbound=0
peer_info=`bitcoin-cli getpeerinfo | grep inbound | sed 's/^.*inbound.*:[^\(true\|false\)]\([a-zA-Z]\+\).*/\1/p'`
for value in ${peer_info}; do
    if [ "${value}" = "true" ]; then
        inbound=$(($inbound +1))
    fi
done

if [ "${connections}" -gt 8 ]; then
    if [ "${inbound}" -gt 0 ]; then
        echo "You're successfully contributing to the network."
        echo "[${connections} peers connected | ${inbound} inbound connections detected]"
    else
        echo "There's likely a problem with your router."
        echo "Ensure you're forwarding port 8333 to this server and check again."
        echo "[${connections} peers connected | ${inbound} inbound connections detected]"
    fi
elif [ "${connections}" -eq 8 ]; then
        echo "It's very likely that there's a problem with your router."
        echo "Ensure you're forwarding port 8333 to this server and check again."
        echo "[${connections} peers connected | ${inbound} inbound connections detected]"
else
    if [ "${inbound}" -gt 0 ]; then
        echo "You have inbound connections (which is good), but you only have ${connections} peers connected."
        echo "You're probably good to go, but check again in a few minutes to be sure."
        echo "[${connections} peers connected | ${inbound} inbound connections detected]"
    else
        echo "You're not contributing to the network (yet), but it might be too early to tell."
        echo "None of your connections originated from outside your network."
        echo "[${connections} peers connected | ${inbound} inbound connections detected]"
    fi
fi
