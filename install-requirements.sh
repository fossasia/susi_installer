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
DEEPSPEECH=0
QUIET=""
NO_INSTALL_NODE=0
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
        --with-deepspeech)
            DEEPSPEECH=1; shift ;;
        --no-install-node)
            NO_INSTALL_NODE=1; shift ;;
        --quiet)
            QUIET="-q" ; shift ;;
        --help)
            cat <<'EOF'
SUSI.AI Dependency Installer

Possible options:
  --trust-pip      Don't do version checks on pip3, trust it to be new enough
  --branch BRANCH  If no local checkouts are available, use the git remotes
                   with branch BRANCH to get requirement files (default: development)
  --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
  --sudo-cmd CMD   Use CMD instead of the default sudo
  --system-install Try installing necessary programs, only supported for some distributions
  --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
  --with-deepspeech Install DeepSpeech and en-US model data
  --no-install-node Don't install node and npm from NodeSource
                   If Node and NPM are available in sufficiently new versions,
                   no update/install will be done anyway
  --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
  --quiet          Silence pip on installation

EOF
            exit 0
            ;;
        --help-only-options)
            cat <<'EOF'
  --trust-pip      Don't do version checks on pip3, trust it to be new enough
  --branch BRANCH  If no local checkouts are available, use the git remotes
                   with branch BRANCH to get requirement files (default: development)
  --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
  --sudo-cmd CMD   Use CMD instead of the default sudo
  --system-install Try installing necessary programs, only supported for some distributions
  --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
  --with-deepspeech Install DeepSpeech and en-US model data
  --no-install-node Don't install node and npm from NodeSource
                   If Node and NPM are available in sufficiently new versions,
                   no update/install will be done anyway
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

#
# On our raspi images we install DeepSpeech in any case
if [ $RASPI = 1 ] ; then
    DEEPSPEECH=1
fi


APTINSTALL="apt-get install --no-install-recommends -y"
APTPKGS="git wget sox default-jre-headless vlc-bin vlc-plugin-base flac python3 python3-pip python3-setuptools libatlas3-base flite curl"
APTPKGSbin="python3-levenshtein python3-pyaudio"

DNFINSTALL="dnf install -y"
DNFPKGScentos="git wget java-1.8.0-openjdk-headless vlc flac python3 python3-pip python3-setuptools blas flite curl"
DNFPKGS="$DNFPKGScentos sox"
DNFPKGSbin="python3-Levenshtein python3-pyaudio"

ZYPPERINSTALL="zypper install --no-recommends -y"
ZYPPERPKGS="git wget sox java-1_8_0-openjdk-headless vlc flac python3 python3-pip python3-setuptools libopenblas_pthreads0 flite curl"
ZYPPERPKGSbin="python3-Levenshtein python3-PyAudio"

PACMANINSTALL="pacman -Syu --noconfirm"
PACMANPKGS="git wget curl sox jre-openjdk-headless vlc flac python-pip python-setuptools blas flite curl"
PACMANPKGSbin="python-levenshtein python-pyaudio"

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
        Arch)      targetSystem=arch  ;; 
        Manjaro)   targetSystem=manjaro  ;;
        Pop)       targetSystem=pop  ;;
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
    debian|ubuntu|raspi|linuxmint|pop) sysInstaller=apt ;;
    fedora|centos)                 sysInstaller=dnf ;;
    opensuse-leap)                 sysInstaller=zypper ;;
    manjaro|arch)                  sysInstaller=pacman ;;
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
        $SUDOCMD apt-get update || true
        $SUDOCMD $APTINSTALL $APTPKGS || true
        $SUDOCMD $APTINSTALL $APTPKGSbin || true
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
    elif [ $sysInstaller = pacman ] ; then
        $SUDOCMD pacman -Syy
        $SUDOCMD $PACMANINSTALL $PACMANPKGS
        $SUDOCMD $PACMANINSTALL $PACMANPKGSbin
    else
        echo "Unknown system installer $sysInstaller, currently only apt , dnf or pacman supported" >&2
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
        $SUDOCMD apt-get clean
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
# Node/NPM installation via nodesource, see
# https://github.com/nodesource/distributions/blob/master/README.md

# require_minimal_version is adjusted from etherpad-lite/bin/installDeps.sh
require_minimal_version() {
  PROGRAM_LABEL="$1"
  VERSION_STRING="$2"
  REQUIRED_MAJOR="$3"
  REQUIRED_MINOR="$4"

  # Flag -s (--only-delimited on GNU cut) ensures no string is returned
  # when there is no match
  DETECTED_MAJOR=$(echo $VERSION_STRING | cut -s -d "." -f 1)
  DETECTED_MINOR=$(echo $VERSION_STRING | cut -s -d "." -f 2)

  if [ -z "$DETECTED_MAJOR" ]; then
    printf 'Cannot extract %s major version from version string "%s"\n' "$PROGRAM_LABEL" "$VERSION_STRING" >&2
    return 1
  fi

  if [ -z "$DETECTED_MINOR" ]; then
    printf 'Cannot extract %s minor version from version string "%s"\n' "$PROGRAM_LABEL" "$VERSION_STRING" >&2
    return 1
  fi

  case "$DETECTED_MAJOR" in
      ''|*[!0-9]*)
        printf '%s major version from "%s" is not a number. Detected: "%s"\n' "$PROGRAM_LABEL" "$VERSION_STRING" "$DETECTED_MAJOR" >&2
        return 1
        ;;
  esac

  case "$DETECTED_MINOR" in
      ''|*[!0-9]*)
        printf '%s minor version from "%s" is not a number. Detected: "%s"\n' "$PROGRAM_LABEL" "$VERSION_STRING" "$DETECTED_MINOR" >&2
        return 1
  esac

  if [ "$DETECTED_MAJOR" -lt "$REQUIRED_MAJOR" ] || ([ "$DETECTED_MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$DETECTED_MINOR" -lt "$REQUIRED_MINOR" ]); then
    printf 'Your %s version "%s" is too old. %s %d.%d.x or higher is required.\n' "$PROGRAM_LABEL" "$VERSION_STRING" "$PROGRAM_LABEL" "$REQUIRED_MAJOR" "$REQUIRED_MINOR" >&2
    return 1
  fi
}


if [ $NO_INSTALL_NODE = 0 ] ; then
    do_node_install=0
    NODEJS=""
    if prog_available node ; then
        NODEJS=node
    elif prog_available nodejs ; then
        NODEJS=nodejs
    else
        # try first to install system packages
        # protect against failure in case the package cannot be found
        if [ "$sysInstaller" = apt ] ; then
            $SUDOCMD $APTINSTALL nodejs npm || true
        elif [ "$sysInstaller" = dnf ] ; then
            $SUDOCMD $DNFINSTALL nodejs || true
        elif [ "$sysInstaller" = zypper ] ; then
            $SUDOCMD $ZYPPERINSTALL nodejs6 || true
        else
            echo "Unknown system installer $sysInstaller, currently only apt or dnf supported" >&2
            exit 1
        fi
    fi
    # redo the check, maybe installation didn't succeed
    if prog_available node ; then
        NODEJS=node
    elif prog_available nodejs ; then
        NODEJS=nodejs
    else
        do_node_install=1
    fi
    if [ -n "$NODEJS" ] ; then
        # requirements for node and npm from etherpad-lite/bin/installDeps.sh
        minNodeMajor=10
        minNodeMinor=13
        minNpmMajor=5
        minNpmMinor=5
        # check for version number of node
        nodeVers=$($NODEJS --version)
        nodeVers=${nodeVers#v} # remove initial v if there
        if ! require_minimal_version "nodejs" "$nodeVers" $minNodeMajor $minNodeMinor ; then
            do_node_install=1
        fi
        if [ $do_node_install = 0 ] ; then
            # we need to check extra for npm, which might *not* be installed
            # Debian eg splits npm from node
            NPM=""
            if prog_available npm ; then
                NPM="npm"
            else
                do_node_install=1
            fi
            if [ -n "$NPM" ] ; then
                npmVers=$($NPM --version)
                if ! require_minimal_version npm "$npmVers" $minNpmMajor $minNpmMinor ; then
                    do_node_install=1
                fi
            fi
        fi
    fi
    if [ $do_node_install = 1 ] ; then
        if [ "$sysInstaller" = apt ] ; then
            curl -sL https://deb.nodesource.com/setup_lts.x | $SUDOCMD -E bash -
            $SUDOCMD $APTINSTALL nodejs || true
        elif [ "$sysInstaller" = dnf ] ; then
            curl -sL https://rpm.nodesource.com/setup_lts.x | $SUDOCMD -E bash -
        elif [ "$sysInstaller" = zypper ] ; then
            # TODO not sure whether this is supported
            $SUDOCMD $ZYPPERINSTALL nodejs6
        else
            echo "Unknown system installer $sysInstaller, currently only apt or dnf supported" >&2
            exit 1
        fi
    fi
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
        echo "at least at version 19!" >&2
        exit 1
    fi
    if [ "$pipversion" -lt 19 ] ; then
        echo "pip3 version \`$pipversion' is less than the required version number 19" >&2
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

# Copy or download requirement files
for i in $reqs ; do
    d=${i%:*}
    f=${i#*:}
    if [ -d $d ] && [ -r $d/$f ] ; then
        cp $d/$f $tmpdir/$i
    else
        p="$d/$BRANCH/$f"
        wget -q -O $tmpdir/$i https://raw.githubusercontent.com/fossasia/$p
    fi
done

# Install pips
for i in $reqs ; do
    $SUDOCMD $PIP install --extra-index-url https://repo.fury.io/fossasia/ -r $tmpdir/$i
done

if [ $DEEPSPEECH = 1 ] ; then
    $SUDOCMD $PIP install deepspeech==0.8.*
    # check which version is actually installed
    DSVersion=$(pip3 show deepspeech | grep ^Version | awk '{print$2}')
    # we need to find out where SpeechRecognition is installed
    sr_dir=$(pip3 show SpeechRecognition | grep ^Location | awk '{print$2}' 2>/dev/null)
    if [ ! -d "$sr_dir/speech_recognition" ] ; then
        echo "Cannot find directory of SpeechRecognition!" >&2
        exit 1
    fi
    $SUDOCMD mkdir -p "$sr_dir/speech_recognition/deepspeech-data/en-US"
    echo "Downloading DeepSpeech model data - this might take some time!"
    for i in pbmm tflite scorer ; do
        if [ ! -r "$sr_dir/speech_recognition/deepspeech-data/en-US/deepspeech-${DSVersion}-models.$i" ] ; then
            $SUDOCMD wget -nv -O "$sr_dir/speech_recognition/deepspeech-data/en-US/deepspeech-${DSVersion}-models.$i" \
                https://github.com/mozilla/DeepSpeech/releases/download/v${DSVersion}/deepspeech-${DSVersion}-models.$i
        fi
    done
fi

# cleanup
if [ $CLEAN = 1 ] ; then
    for i in $reqs ; do
        rm $tmpdir/$i
    done
    rmdir $tmpdir
fi

echo "Finished."


# vim: set expandtab shiftwidth=4 softtabstop=4 smarttab:
