#!/bin/bash
# SUSI.AI Smart Assistant dependency installer script
# Copyright 2019 Norbert Preining
# 
# TODO
# - maybe add an option --try-system-install and then use apt-get etc as far as possible?
#   but how to deal with non-Debian systems
#
set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

PROGS="git wget sox java vlc flac python3 pip3"

TRUSTPIP=0
CLEAN=1
BRANCH=development
RASPI=0
SUDOCMD=sudo
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --trust-pip)
            TRUSTPIP=1 ; shift ;;
        --no-clean)
            CLEAN=0 ; shift ;;
        --raspi)
            RASPI=1 ; shift ;;
        --sudo-cmd)
            SUDOCMD="$2" ; shift ; shift ;;
        --branch)
            BRANCH="$2" ; shift ; shift ;;
        --help)
            cat <<'EOF'
SUSI.AI Dependency Installer

Possible options:
  --trust-pip      Don't do version checks on pip3, trust it to be new enough
  --branch BRANCH  Use branch BRANCH to get requirement files (default: development)
  --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
  --sudo-cmd CMD   Use CMD instead of the default sudo
  --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3

EOF
            exit 0
            ;;
        *)
            echo "Unknown option or argument: $key" >&2
            exit 1
    esac
done




#
# Check necessary programs are available
#
prog_available() {
    if ! [ -x "$(command -v $1)" ]; then
        return 1
    fi
}
MISSINGPROGS=""
for i in $PROGS ; do
    if ! prog_available $i ; then
        MISSINGPROGS="$i $MISSINGPROGS"
    fi
done
if [ -n "$MISSINGPROGS" ] ; then
    echo "Required programs are not available, please install them first:" >&2
    echo "$MISSINGPROGS" >&2
    exit 1
fi

#
# check that pip3 is at least at version 18
#
UPDATEPIP=0
if [ $TRUSTPIP = 0 ] ; then
    pipversion=$(pip3 --version)
    pipversion=${pipversion#pip }
    pipversion=${pipversion%%.*}
    pipversion=${pipversion%% *}
    UNKNOWN=0
    case "$pipversion" in
        ''|*[!0-9]*) UNKNOWN=1 ;;
    esac
    if [ $UNKNOWN = 1 ] ; then
        echo "Cannot determine pip version number. Got \`$pipversion\' from \`pip3 --version\'" >&2
        echo "Please use \`--trust-pip\' to disable these checks if you are sure that pip is" >&2
        echo "at least at version 18!" >&2
        exit 1
    fi
    if [ "$pipversion" -lt 18 ] ; then
        echo "pip3 version \`$pipversion\' is less than the required version number 18" >&2
        echo "Will update pip3 using itself."
        UPDATEPIP=1
    fi
fi

PIP=pip3
if [ $CLEAN = 1 ] ; then
    PIP="pip3 --no-cache-dir -q"
fi

if [ $UPDATEPIP = 1 ] ; then
    $SUDOCMD $PIP install -U pip
fi


reqs="
    susi_installer:requirements.txt
    susi_python:requirements.txt
    susi_linux:requirements.txt
    susi_installer:requirements-optional.txt
"
reqspi="
    susi_linux:requirements-rpi.txt
"

if [ $RASPI = 1 ] ; then
    reqs="$reqs $reqspi"
fi

# Create temp dir
tmpdir=$(mktemp -d)

# Download requirement files
for i in $reqs ; do
    p=$(echo $i | sed -e s+:+/$BRANCH/+)
    wget -q -O $tmpdir/$i https://raw.githubusercontent.com/fossasia/$p
done

# Install pips
for i in $reqs ; do
    $SUDOCMD $PIP install -r $tmpdir/$i
done

# cleanup
if [ $CLEAN = 1 ] ; then
    for i in $reqs ; do
        rm $tmpdir/$i
    done
    rmdir $tmpdir
fi

echo "Finished."


# vim: set expandtab shiftwidth=4 softtabstop=4 smarttab:
