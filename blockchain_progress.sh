#!/bin/bash

if [ ! -f ~/.bitcoin/bitcoin.conf ]; then
    echo "ERROR: ~/.bitcoin/bitcoin.conf not found." 1>&2

    if [ "`id -u`" = "0" ]; then
        echo "NOTICE: This script DOES NOT need to be run as root." 1>&2
    fi

    exit 1
fi

if [ "$*" == "--poll" ]; then
    echo
    while [ 0 -eq 0 ]; do
        local_count=`bitcoin-cli getblockcount 2>&1`
        web_count=`wget -O - http://blockchain.info/q/getblockcount 2>/dev/null`

        echo -ne "\r\033[KDownloaded:\t${local_count} of ${web_count}\t\t( $((${local_count} * 100 / ${web_count}))% )"
        sleep 3
    done
else
    local_count=`bitcoin-cli getblockcount 2>&1`
    web_count=`wget -O - http://blockchain.info/q/getblockcount 2>/dev/null`

    echo "Downloaded ${local_count} of ${web_count} ( $((${local_count} / ${web_count} * 100))% )"
fi

