#!/bin/bash
if [ "`id -u`" != "0" ]; then
    echo "ERROR: This script must be run as root." 1>&2
    exit 1
fi

if [ ! -f "lib/install.sh" ]; then
    echo "Unable to source installation functions." 1>&2
    exit 1
fi
. lib/install.sh

latest_version=`get_latest_version`
current_version=''
if [ -f '.version' ]; then
    current_version=`cat .version | head -n1`
fi

if [ -z "${latest_version}" ]; then
    echo "ERROR: Unable to determine the latest version from the web." 1>&2
    exit 1
fi

if [ "${current_version}" != "${latest_version}" ]; then
    echo "Current: ${current_version}"
    echo "Latest:  ${latest_version}"
    VERSION="${latest_version}"

    echo "Upgrading to: ${latest_version}"

    /etc/init.d/bitcoind status 1>/dev/null 2>/dev/null
    if [ "$?" -eq 0 ]; then
        echo "Shutting down the Bitcoin-QT Daemon"
        /etc/init.d/bitcoind stop
    fi

    echo "Downloading Bitcoin-QT ${VERSION}"
    download_bitcoind

    echo "Installing Bitcoin-QT binary files..."
    install_binaries

    # Start BitcoinQT Daemon
    echo "Starting Bitcoin-QT Daemon..."
    /etc/init.d/bitcoind start
    sleep 3
    /etc/init.d/bitcoind status

    echo "${VERSION}" > .version
    exit 0
else
    echo "Up to date. (v${latest_version})"
    exit 0
fi
