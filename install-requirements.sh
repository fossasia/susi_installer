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
DISTPKGS=0
QUIET=""
SYSTEMINSTALL=0
SYSINSTALLER=""
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
        --use-dist-packages)  # undocumented on purpose!! Should only be used for Raspi builds!
            DISTPKGS=1 ; shift ;;
        --sudo-cmd)
            SUDOCMD="$2" ; shift ; shift ;;
        --system-install)
            SYSTEMINSTALL=1 ; shift ;;
        --sys-installer)
            SYSINSTALLER="$2" ; shift ; shift ;;
        --branch)
            BRANCH="$2" ; shift ; shift ;;
        --quiet)
            QUIET="-q" ; shift ;;
        --help)
            cat <<'EOF'
SUSI.AI Dependency Installer

Possible options:
  --trust-pip      Don't do version checks on pip3, trust it to be new enough
  --branch BRANCH  Use branch BRANCH to get requirement files (default: development)
  --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
  --sudo-cmd CMD   Use CMD instead of the default sudo
  --system-install Try installing necessary programs, only supported for some distributions
  --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
  --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
  --quiet          Silence pip on installation

EOF
            exit 0
            ;;
        *)
            echo "Unknown option or argument: $key" >&2
            exit 1
    esac
done


APTINSTALL="apt-get install --no-install-recommends -y"
APTPKGS="git wget sox default-jre-headless vlc-bin flac python3 python3-pip python3-setuptools libatlas3-base"
APTPKGSbin="python3-levenshtein python3-pyaudio"

DNFINSTALL="dnf install -y"
DNFPKGScentos="git wget java-1.8.0-openjdk-headless vlc flac python3 python3-pip python3-setuptools blas"
DNFPKGS="$DNFPKGScentos sox"
DNFPKGSbin="python3-Levenshtein python3-pyaudio"

ZYPPERINSTALL="zypper install --no-recommends -y"
ZYPPERPKGS="git wget sox java-1_8_0-openjdk-headless vlc flac python3 python3-pip python3-setuptools libopenblas_pthreads0"
ZYPPERPKGSbin="python3-Levenshtein python3-PyAudio"


targetSystem="unknown"
sysInstaller="unknown"
if [ -x "$(command -v lsb_release)" ]; then
    vendor=`lsb_release -i -s 2>/dev/null`
    case "$vendor" in
        Debian)    targetSystem=debian  ;;
        Raspbian)  targetSystem=raspi   ;;
        Ubuntu)    targetSystem=ubuntu  ;;
        LinuxMint) targetSystem=linuxmint ;;
        CentOS)    targetSystem=centos  ;;
        Fedora)    targetSystem=fedora  ;;
        openSUSE)  targetSystem=opensuse-leap ;;
        *)         targetSystem=unknown ;;
    esac
else
    # TODO
    # how to check ubuntu/mint/fedora/raspi ... ?????
    # what are the ID names there, maybe leave out lsb_release completely?
    if [ -r /etc/os-release ] ; then
        source /etc/os-release
        if [ -n "$ID" ] ; then
            targetSystem="$ID"
        fi
    elif [ -r /etc/debian_version ] ; then
        targetSystem="debian"
    fi
fi

sysInstaller=unknown
case $targetSystem in
    debian|ubuntu|raspi|linuxmint) sysInstaller=apt ;;
    fedora|centos)                 sysInstaller=dnf ;;
    opensuse-leap)                 sysInstaller=zypper ;;
esac


if [ $SYSTEMINSTALL = 1 ] ; then
    if [ -n "$SYSINSTALLER" ] ; then
        if [ $sysInstaller = unknown ] ; then
            echo "Manually selection system installation method $SYSINSTALLER"
            sysInstaller="$SYSINSTALLER"
        else
            if [ ! $sysInstaller = "$SYSINSTALLER" ] ; then
                echo "Discrepancy: detected $sysInstaller, but $SYSINSTALLER was selected - giving up!" >&2
                exit 1
            fi
        fi
    fi
    if [ $sysInstaller = unknown ] ; then
        echo "Unknown installer system, please define one with --sys-installer apt|dnf" >&2
        exit 1
    elif [ $sysInstaller = apt ] ; then
        $SUDOCMD $APTINSTALL $APTPKGS
        $SUDOCMD $APTINSTALL $APTPKGSbin
    elif [ $sysInstaller = dnf ] ; then
        if [ $targetSystem = fedora ] ; then
            $SUDOCMD $DNFINSTALL https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
        elif [ $targetSystem = centos ] ; then
            # not sure if that works on older centos, though?
            $SUDOCMD $DNFINSTALL --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            $SUDOCMD $DNFINSTALL --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
        else
            echo "Don't know how to activate sources for vlc on $targetSystem!" >&2
            echo "If vlc is not installed the next command will probably fail." >&2
        fi
        if [ $targetSystem = centos ] ; then
            $SUDOCMD $DNFINSTALL $DNFPKGScentos
        else
            $SUDOCMD $DNFINSTALL $DNFPKGS
        fi
        $SUDOCMD $DNFINSTALL $DNFPKGSbin
    elif [ $sysInstaller = zypper ] ; then
        $SUDOCMD $ZYPPERINSTALL $ZYPPERPKGS
        $SUDOCMD $ZYPPERINSTALL $ZYPPERPKGSbin
    else
        echo "Unknown system installer $sysInstaller, currently only apt or dnf supported" >&2
        exit 1
    fi
fi



#
# On Raspberry susibian, install what is necessary
#
RASPIDEPS="
  git openssl wget python3-pip sox libsox-fmt-all flac libasound2-plugins
  libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base
  vlc-plugin-video-splitter flite default-jdk-headless pixz udisks2 ca-certificates
  hostapd dnsmasq usbmount python3-setuptools python3-pyaudio
"
# TODO
# remove python3-pyaudio from the above when fury is updated with binary builds
# for Py3.7/arm

#
# TODO
# is python3-cairo really necessary????
# removed for now

RASPIPYTHONDEPS="
  python3-flask python3-requests python3-requests-futures python3-service-identity
  python3-pyaudio python3-levenshtein python3-pafy python3-colorlog python3-psutil
  python3-watson-developer-cloud python3-aiohttp python3-bs4 python3-mutagen
  python3-alsaaudio
"

if [ $RASPI = 1 ] ; then
    $SUDOCMD apt-get update
    $SUDOCMD apt-get install --no-install-recommends -y $RASPIDEPS
    if [ $DISTPKGS = 1 ] ; then
        $SUDOCMD apt-get install --no-install-recommends -y $RASPIPYTHONDEPS
    fi
    if [ $CLEAN = 1 ] ; then
        apt-get clean
    fi
fi

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
# check whether setuptools is installed
{
    ret=`pip3 show setuptools || true`
    if [ -z "$ret" ] ; then
        echo "Missing dependency: python3-setuptools, please install that first!" >&2
        exit 1
    fi
}

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
        echo "at least at version 19!" >&2
        exit 1
    fi
    if [ "$pipversion" -lt 19 ] ; then
        echo "pip3 version \`$pipversion\' is less than the required version number 19" >&2
        echo "Will update pip3 using itself."
        UPDATEPIP=1
    fi
fi

PIP="pip3 $QUIET"
if [ $CLEAN = 1 ] ; then
    PIP="$PIP --no-cache-dir"
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
    $SUDOCMD $PIP install --extra-index-url https://repo.fury.io/fossasia/ -r $tmpdir/$i
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
