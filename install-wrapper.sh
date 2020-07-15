#!/bin/bash
# SUSI.AI install wrapper for both the requirements and susi installer
# Copyright 2018-2020 Norbert Preining
#
set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ] ; then
	echo "SUSI.AI installer"
	echo
	echo "Possible options for requirements installer:"
	./install-requirements.sh --help-only-options
	echo
	echo "Possible options for SUSI.AI system installer:"
	./install.sh --help-only-options
	echo
	echo "Default options are"
	echo "  --system-install --with-deepspeech"
	exit 0
fi

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
                   with branch BRANCH to get requirement files (default: development)
# --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
# --sudo-cmd CMD   Use CMD instead of the default sudo
# --system-install Try installing necessary programs, only supported for some distributions
# --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
# --with-deepspeech Install DeepSpeech and en-US model data
# --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
# --quiet          Silence pip on installation



