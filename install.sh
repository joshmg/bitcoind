#!/bin/bash
if [ "`id -u`" != "0" ]; then
    echo "ERROR: This script must be run as root." 1>&2
    exit 1
fi

VERSION='0.9.2.1' # BitcoinQT Version
FILE="bitcoin-${VERSION}-linux"
DAEMON_USER='bitcoin'

# Detect 64 Bit
BIT=32
if [ "`uname -m`" = "x86_64" ]; then
    BIT=64
fi

function hash() {
    echo -n "$1" | md5sum | sed 's/\([0-9a-zA-Z]\+\).*/\1/p' | tail -n1 
}

function random_hash() {
    tmp=`date +"%Y-%m-%d %H:%M:%S $RANDOM"`
    tmp=`hash "${tmp}"`
    tmp=`hash "${tmp}"`
    hash "${tmp}"
}

# Create the daemon user
echo "Creating daemon user: ${DAEMON_USER}"
useradd --create-home "${DAEMON_USER}" --password `random_hash` >/dev/null 2>/dev/null
groups "${DAEMON_USER}" >/dev/null 2>/dev/null
if [ "$?" -gt 0 ]; then
    echo "Error Creating Daeon User. Aborting." 1>&2
    exit 1
fi
passwd -l "${DAEMON_USER}" >/dev/null # Lock the account

# Download bitcoin-qt
echo "Downloading Bitcoin-QT"
wget "https://bitcoin.org/bin/${VERSION}/${FILE}.tar.gz"
tar -xzf "${FILE}.tar.gz"
cp "${FILE}/bin/${BIT}/bitcoind" "/home/${DAEMON_USER}/."
chown ${DAEMON_USER}:${DAEMON_USER} "/home/${DAEMON_USER}/bitcoind"
chmod 770 "/home/${DAEMON_USER}/bitcoind"
cp "${FILE}/bin/${BIT}/bitcoin-cli" "/usr/bin/."
chown root:root "/usr/bin/bitcoin-cli"
chmod 755 "/usr/bin/bitcoin-cli"

# Clean Up
rm -r "${FILE}"
rm "${FILE}.tar.gz"

# Install init.d script
echo "Installing init.d script"
cp init.d/bitcoind /etc/init.d/.
chown root:root /etc/init.d/bitcoind
chmod 770 /etc/init.d/bitcoind
update-rc.d bitcoind defaults

# Create bitcoin.conf
mkdir "/home/${DAEMON_USER}/.bitcoin"
config_contents="rpcuser=`random_hash`\nrpcpassword=`random_hash``random_hash`\n"
echo -e "${config_contents}" > "/home/${DAEMON_USER}/.bitcoin/bitcoin.conf"
chmod -R 770 "/home/${DAEMON_USER}/.bitcoin"
chown -R ${DAEMON_USER}:${DAEMON_USER} "/home/${DAEMON_USER}/.bitcoin"

/etc/init.d/bitcoind start
sleep 3
/etc/init.d/bitcoind status

echo 
echo "########## Notice ##########"
echo "To use the bitcoin-cli, execute:"
echo -e "if [ ! -d ~/.bitcoin ]; then mkdir ~/.bitcoin; fi;\necho -e '${config_contents}' > ~/.bitcoin/bitcoin.conf;\nchmod -R 770 ~/.bitcoin"
echo "############################"
echo

