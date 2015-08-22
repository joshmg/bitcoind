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

if [ ! -f "config" ]; then
    echo "Unable to source configuration settings." 1>&2
    exit 1
fi
. config

prompt_for_variant

echo "Determining latest version..."
VERSION=`get_latest_version "${VARIANT}"`
echo "Using Version: ${VERSION} ${VARIANT}"


echo "Creating daemon user: ${DAEMON_USER}"
create_daemon_user

echo "Downloading Bitcoin-QT ${VERSION} ${VARIANT}"
download_bitcoind "${VARIANT}"

echo "Installing Bitcoin-QT binary files... ${VARIANT}"
install_binaries "${VARIANT}"

echo "Installing init.d script..."
install_init_d

echo "Creating bitcoin.conf..."
create_bitcoin_conf

echo "${VERSION}" > .version
echo "${VARIANT}" >> .version

# Start BitcoinQT Daemon
echo "Starting Bitcoin-QT Daemon..."
/etc/init.d/bitcoind start
sleep 3
/etc/init.d/bitcoind status

echo 
echo "########################## NOTICE ############################"
echo "# If you want to use the bitcoin-cli you must first execute: #"
echo "if [ ! -d ~/.bitcoin ]; then mkdir ~/.bitcoin; fi;"
echo "echo -e '${config_contents}' > ~/.bitcoin/bitcoin.conf;"
echo "chmod -R 770 ~/.bitcoin"
echo "##############################################################"
echo

