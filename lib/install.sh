#!/bin/bash

if [ ! -f "config" ]; then
    echo "Unable to source configuration settings." 1>&2
    exit 1
fi
. config

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

function compute_xt_filename() {
    filename_version='0.11.0'
    filename_release="${VERSION: -1}"
    filename="bitcoin-xt-${filename_version}-${filename_release}" # NOTE: Expect their filename to change in the future...
    echo "${filename}"
}

# Determine the latest version via the web.
function get_latest_version() {
    if [[ "$1" = "CLASSIC" ]]; then
        FALLBACK_VERSION='v0.11.2'
        version=`wget -q --level=1 -O - https://github.com/bitcoinclassic/bitcoinclassic/releases/latest | sed -n 's/.*releases\/tag\/\([^"]\+\).*$/\1/p' | head -n1`
    elif [[ "$1" = "XT" ]]; then
        FALLBACK_VERSION='v0.11I'
        version=`wget -q --level=1 -O - https://github.com/bitcoinxt/bitcoinxt/releases/latest | sed -n 's/.*releases\/tag\/\([^"]\+\).*$/\1/p' | head -n1`
    else
        FALLBACK_VERSION='0.9.2.1'
        version=`wget -O - https://bitcoin.org/en/download 2>/dev/null | grep -i "Latest version:" | sed 's/^.*version:[^0-9]*\([0-9\.]\+\).*/\1/p' | head -n1`
    fi

    if [ -z "${version}" ]; then
        echo "WARNING: Unable to determine the latest version from the web. Falling back to version: ${FALLBACK_VERSION}" 1>&2
        version="${FALLBACK_VERSION}"
    fi

    echo "${version}"
}

# Create the daemon user
function create_daemon_user() {
    if [ -z "${DAEMON_USER}" ]; then
        echo "ERROR: Daemon username not set." 1>&2
        exit 1
    fi

    useradd --create-home "${DAEMON_USER}" --password `random_hash` >/dev/null 2>/dev/null
    groups "${DAEMON_USER}" >/dev/null 2>/dev/null
    if [ "$?" -gt 0 ]; then
        echo "Error creating daemon user. Aborting." 1>&2
        exit 1
    fi
    passwd -l "${DAEMON_USER}" >/dev/null # Lock the account
}

# Download bitcoin-qt
function download_bitcoind() {
    if [ -z "${BIT}" ]; then
        echo "ERROR: CPU bit not set." 1>&2
        exit 1
    fi

    if [[ "$1" = 'CLASSIC' ]]; then
        filename_version="${VERSION}"
        if [[ "${VERSION}" = 'v0.11.2.cl1' ]]; then
            filename_version='0.11.2' # "Hack"
        fi
        file="bitcoin-${filename_version}-linux${BIT}" 
        wget "https://github.com/bitcoinclassic/bitcoinclassic/releases/download/${VERSION}/${file}.tar.gz" --progress=bar:force 2>&1 | tail -f -n +8
    elif [[ "$1" = 'XT' ]]; then
        # NOTE: BTC-XT binary name conventions are inconsistent and can't be dynamically parsed.
        #       The version must be updated manually:
        filename="`compute_xt_filename`-linux${BIT}"
        file="${filename}" # NOTE: Expect their filename to change in the future...
        echo "Downloading: https://github.com/bitcoinxt/bitcoinxt/releases/download/${VERSION}/${file}.tar.gz"
        wget "https://github.com/bitcoinxt/bitcoinxt/releases/download/${VERSION}/${file}.tar.gz" --progress=bar:force 2>&1 | tail -f -n +8
    else
        if [ -z "${VERSION}" ]; then
            echo "ERROR: Bitcoin-QT version not set." 1>&2
            exit 1
        fi

        file="bitcoin-${VERSION}-linux${BIT}"
        compare_version "${VERSION}" "0.10.0"
        if [ "$?" -gt 1 ]; then
            # Backwards compatibility for version < 0.10.0
            file="bitcoin-${VERSION}-linux"
        fi

        # wget "https://bitcoin.org/bin/${VERSION}/${file}.tar.gz" >/dev/null 2>/dev/null
        wget "https://bitcoin.org/bin/bitcoin-core-${VERSION}/${file}.tar.gz" --progress=bar:force 2>&1 | tail -f -n +8
    fi
}

# Install Bitcoin binaries
# Note: this function consumes the tarball
function install_binaries() {
    filename_version="${VERSION}"
    file="bitcoin-${filename_version}-linux${BIT}"
    if [[ "$1" = 'CLASSIC' ]]; then
        if [[ "${VERSION}" = 'v0.11.2.cl1' ]]; then
            filename_version='0.11.2' # "Hack"
            file="bitcoin-${filename_version}-linux${BIT}"
        fi
    fi

    unzipped_filename="bitcoin-${filename_version}"
    if [[ "$1" = 'XT' ]]; then
        # NOTE: BTC-XT binary name conventions are inconsistent. This will very likely break in the future.
        unzipped_filename="`compute_xt_filename`"
        filename="${unzipped_filename}-linux${BIT}"
        file="${filename}"
    else
        compare_version "${filename_version}" "0.10.0"
        if [ "$?" -gt 1 ]; then
            # Backwards compatibility for version < 0.10.0
            file="bitcoin-${filename_version}-linux"
        fi
    fi

    if [ ! -f "${file}.tar.gz" ]; then
        echo "ERROR: Cannot find bitcoind package. Was it downloaded?" 1>&2
        exit 1
    fi

    tar -xzf "${file}.tar.gz"

    use_legacy=1
    if [[ "$1" = 'XT' ]]; then
        use_legacy=0
    else
        compare_version "${filename_version}" "0.10.0"
        if [ "$?" -lt 2 ]; then
            use_legacy=0
        fi
    fi

    if [ "${use_legacy}" -eq 0 ]; then
        cp "${unzipped_filename}/bin/bitcoind" "/home/${DAEMON_USER}/."
        cp "${unzipped_filename}/bin/bitcoin-cli" "/usr/bin/."
    else
        # Backwards compatibility for version < 0.10.0
        cp "${file}/bin/${BIT}/bitcoind" "/home/${DAEMON_USER}/."
        cp "${file}/bin/${BIT}/bitcoin-cli" "/usr/bin/."
    fi

    chown ${DAEMON_USER}:${DAEMON_USER} "/home/${DAEMON_USER}/bitcoind"
    chmod 770 "/home/${DAEMON_USER}/bitcoind"
    chown root:root "/usr/bin/bitcoin-cli"
    chmod 755 "/usr/bin/bitcoin-cli"

    # Clean Up
    if [ "${use_legacy}" -eq 0 ]; then
        rm -r "${unzipped_filename}"
    else
        # Backwards compatibility for version < 0.10.0
        rm -r "${file}"
    fi
    rm "${file}.tar.gz"
}

# Install init.d script
function install_init_d() {
    cp init.d/bitcoind /etc/init.d/.
    chown root:root /etc/init.d/bitcoind
    chmod 770 /etc/init.d/bitcoind
    if [ -z "`which update-rc.d`" ]; then
        echo "WARNING: update-rc.d not found. Script will not auto-start on boot." 1>&2
    else
        update-rc.d bitcoind defaults >/dev/null
    fi
}

# Create bitcoin.conf
function create_bitcoin_conf() {
    if [ -z "${DAEMON_USER}" ]; then
        echo "ERROR: Daemon username not set." 1>&2
        exit 1
    fi

    if [ ! -d "/home/${DAEMON_USER}/.bitcoin" ]; then
        mkdir "/home/${DAEMON_USER}/.bitcoin"
    fi

    config_contents="rpcuser=`random_hash`\nrpcpassword=`random_hash``random_hash`\n"
    echo -e "${config_contents}" > "/home/${DAEMON_USER}/.bitcoin/bitcoin.conf"
    chmod -R 770 "/home/${DAEMON_USER}/.bitcoin"
    chown -R ${DAEMON_USER}:${DAEMON_USER} "/home/${DAEMON_USER}/.bitcoin"
}

# Version String Comparison
# 0 : Equal; 1 : First Param GT; 1 : Second Param GT
# Kudos: Dennis Williamson http://goo.gl/u81W2m
function compare_version() {
    if [[ $1 == $2 ]]; then
        return 0
    fi

    if [ "${USE_XT}" -eq 0 ]; then
        return 1
    fi

    local IFS=.
    local i ver1=($1) ver2=($2)

    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        elif ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done

    return 0
}

function prompt_for_variant() {
    if [[ "${CONFIG_VARIANT}" = 'CORE' ]]; then
        USE_XT=0
        USE_CLASSIC=0
        VARIANT="${CONFIG_VARIANT}"
    elif [[ "${CONFIG_VARIANT}" = 'CLASSIC' ]]; then
        USE_XT=0
        USE_CLASSIC=1
        VARIANT="${CONFIG_VARIANT}"
    elif [[ "${CONFIG_VARIANT}" = 'XT' ]]; then
        USE_XT=1
        USE_CLASSIC=0
        VARIANT="${CONFIG_VARIANT}"
    else
        USE_XT=1
        USE_CLASSIC=0
        echo 'Would you like to use Bitcoin-XT? Learn more: https://bitcoinxt.software/'
        echo -n '(Y/n) '
        read buff
        if [[ "${buff}" = 'n' ]] || [[ "${buff}" = 'N' ]]; then
            USE_XT=0
        fi
	if [ "${USE_XT}" -eq 0 ]; then
            echo 'Would you like to use Bitcoin Classic? Learn more: https://bitcoinclassic.com/'
            echo -n '(y/N) '
            read buff
            if [[ "${buff}" = 'y' ]] || [[ "${buff}" = 'Y' ]]; then
                USE_CLASSIC=1
            fi
	fi

        VARIANT='CORE'
        if [ "${USE_XT}" -eq 1 ]; then
            VARIANT='XT'
	elif [ "${USE_CLASSIC}" -eq 1 ]; then
	    VARIANT='CLASSIC'
	fi
    fi
}
