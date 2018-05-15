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

prompt_for_variant

latest_version=`get_latest_version "${VARIANT}"`
current_version=''
if [ -f '.version' ]; then
    current_version=`cat .version | head -n1`
    current_variant=`cat .version | tail -n1`
fi

if [ -z "${latest_version}" ]; then
    echo "ERROR: Unable to determine the latest version from the web." 1>&2
    exit 1
fi

if [ "${current_version}" != "${latest_version}" ]; then
    echo "Current: ${current_version} ${current_variant}"
    echo "Latest:  ${latest_version} ${VARIANT}"
    VERSION="${latest_version}"

    echo "Upgrading to: ${latest_version} ${VARIANT}"

    /etc/init.d/bitcoind status 1>/dev/null 2>/dev/null
    if [ "$?" -eq 0 ]; then
        echo "Shutting down the Bitcoin Daemon"
        /etc/init.d/bitcoind stop
    fi

    echo "Downloading ${VERSION}"
    download_bitcoind "${VARIANT}"

    echo "Installing binary files..."
    install_binaries "${VARIANT}"

    # Start BitcoinQT Daemon
    echo "Starting Bitcoin Daemon..."
    /etc/init.d/bitcoind start
    sleep 3
    /etc/init.d/bitcoind status

    echo "${VERSION}" > .version
    echo "${VARIANT}" >> .version
    exit 0
else
    if [[ "${USE_XT}" -eq 1 ]]; then
        echo "Up to date. (${latest_version})"
    else
        echo "Up to date. (v${latest_version})"
    fi
    exit 0
fi
