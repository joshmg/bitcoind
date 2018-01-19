#!/bin/bash

USE_BCH=1

if [ ! -f ~/.bitcoin/bitcoin.conf ]; then
    echo "ERROR: ~/.bitcoin/bitcoin.conf not found." 1>&2

    if [ "`id -u`" = "0" ]; then
        echo "NOTICE: This script DOES NOT need to be run as root." 1>&2
    fi

    exit 1
fi

if [ "$*" == "--poll" ]; then
    j=0
    while [ true ]; do
        for i in {0..9}; do
            local_count=`bitcoin-cli getblockcount 2>&1`
            if [ "$?" -gt 0 ]; then
                echo "ERROR: Can't connect to bitcoind. Is it running?" 1>&2
                exit 1
            fi

            if [ $i = 0 ]; then
                if [ ${USE_BCH} ]; then 
                    web_count=`wget -O - https://bitcoincash.blockexplorer.com/api/status?q=getBlockCount 2>/dev/null | sed -n 's/.*"blocks":\([0-9]\+\),.*/\1/p'`
                else
                    web_count=`wget -O - http://blockchain.info/q/getblockcount 2>/dev/null`
                fi
            fi

            echo -ne "\r\033[KDownloaded:\t${local_count} of ${web_count}\t\t( $((${local_count} * 100 / ${web_count}))% )"

            # Handle Ellipse
            if [ $j -ge 1 ]; then   echo -n " .";           else echo -ne "  "; fi
            if [ $j -ge 2 ]; then   echo -n ".";            else echo -ne " ";  fi
            if [ $j -ge 3 ]; then   echo -n ".";    j=0;    else echo -ne " ";  fi
            echo -n " "
            j=$(($j +1))

            sleep 3
        done
    done
else
    local_count=`bitcoin-cli getblockcount 2>&1`
    if [ "$?" -gt 0 ]; then
        echo "ERROR: Can't connect to bitcoind. Is it running?" 1>&2
        exit 1
    fi

    if [ ${USE_BCH} ]; then 
        web_count=`wget -O - https://bitcoincash.blockexplorer.com/api/status?q=getBlockCount 2>/dev/null | sed -n 's/.*"blocks":\([0-9]\+\),.*/\1/p'`
    else
        web_count=`wget -O - http://blockchain.info/q/getblockcount 2>/dev/null`
    fi

    echo -e "Downloaded:\t${local_count} of ${web_count}\t\t( $((${local_count} * 100 / ${web_count}))% )"
fi

