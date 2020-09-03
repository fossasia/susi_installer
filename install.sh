#!/bin/bash
# SUSI.AI install wrapper for both the requirements and susi installer
# Copyright 2018-2020 Norbert Preining
#
set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# we use the development branch for now!
GITHUB=https://raw.githubusercontent.com/fossasia/susi_installer/development/

if [ $# -gt 0 ] ; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ] ; then
	echo "SUSI.AI installer"
	echo
	echo "This script runs installs the necessary requirements for SUSI.AI"
	echo "as well as the actual system, by calling the following two commands:"
	echo "   ./install-requirements.sh --system-install --with-deepspeech"
	echo "   ./install-susi.sh --dev"
	echo
	echo "If you need different options, please call the scripts separately!"
	echo "See below for possible options."
	echo
	echo "Possible options for requirements installer:"
	./install-requirements.sh --help-only-options
	echo
	echo "Possible options for SUSI.AI system installer:"
	./install-susi.sh --help-only-options
	echo
	exit 0
    fi
fi

prog_available() {
    if ! [ -x "$(command -v $1)" ]; then
        return 1
    fi
}

if prog_available wget ; then
    downloader="wget --tries=3 -q -O"
elif prog_available curl ; then
    downloader="wget --retry 3 --fail --location --silent --output"
else
    downloader=""
fi

error_download() {
    echo "Cannot find script $1, nor cannot download it." >&2
    echo "Neither wget nor curl is available." >&2
    exit 1
}

check_download() {
    if [ ! -r $1 ] ; then
        if [ -z "$downloader" ] ; then
            error_download $1
        fi
        $downloader ./$1 $GITHUB/$1
    fi
}

echo "Downloading installer scripts ..."
check_download install-requirements.sh
check_download install-susi.sh
echo "Running install-requirements.sh ..."
bash ./install-requirements.sh --system-install --with-deepspeech
echo "Running install-susi.sh ..."
bash ./install-susi.sh --dev


# install-susi.sh options
# --destdir DIR
# --system
# --prefix ARG
# --clean
# --susi-server-user ARG
# --with-coral
# --dev

# install-requirements.sh options
# --trust-pip      Don't do version checks on pip3, trust it to be new enough
# --branch BRANCH  If no local checkouts are available, use the git remotes
#                   with branch BRANCH to get requirement files (default: development)
# --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
# --sudo-cmd CMD   Use CMD instead of the default sudo
# --system-install Try installing necessary programs, only supported for some distributions
# --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
# --with-deepspeech Install DeepSpeech and en-US model data
# --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
# --quiet          Silence pip on installation



