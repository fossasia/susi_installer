#!/bin/bash -e
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

INSTALLERDIR=$(dirname $(realpath "$0"))

#
# Target layout as with the developer-setup.md layout
#
# Two modes of installation: "user" and "system"
# On the RPi we *always* run in user mode and use sudo
# On the Desktop in user mode, no root rights (sudo) are necessary
#   but required pip3 install calls are optionally started with sudo
#
# Installation directory defaults
# User installation
#   DESTDIR = ~/SUSI.AI                 --destdir can override this
#   BINDIR  = $DESTDIR/bin
#   WORKDIR = $DESTDIR
# System installation
#   DESTDIR = $prefix/lib/SUSI.AI       --prefix can be given
#   BINDIR  = $prefix/bin
#   WORKDIR = ~/.SUSI.AI
#
#   In system mode the susi-server starts as user $SUSI_SERVER_USER
#   which defaults to _susiserver and can be configured via --susi-server-user
#
# Layout withing DESTDIR
#   susi_installer
#   susi_linux
#   susi_python
#   susi_server
#   susi_skill_data
#   seeed_voicecard
#   etherpad-lite (for raspi)
# Contents of WORKDIR
#   config.json
#   susidata (link target for susi_server/data)
#   etherpad.db (link target foretherpad-lite/var/dirty.db)

#
# TODO items
# - how would partial replacement of single packages with Debian packages work
# - RedHat and SuSE and Alpine and Mint and ... support ???

#
# determine Debian/Ubuntu release - we don't support anything else at the moment
#                   Raspbian       Debian 9      Ubuntu          Debian 10  Mint
# lsb_release -i    Raspbian       Debian        Ubuntu          Debian     LinuxMint
# lsb_release -r    9.N            9.N           14.04/16.04     10.N       18.2
#
# Ubuntu release: 14.04, 16.04, 18.04, 18.10, 19.04, ...
# Debian release: 9.N (2017/06 released, stretch, current stable, Raspbian), 10 (2019/0? released, buster), 11 (???)
# Raspbian release: 9.N (like Debian stretch)
# Linux Mint: 18.*, 19.*, 18, 19
#
# We classify systems according to distribution and version
# - targetSystem = raspi | debian | ubuntu | mint
vendor=`lsb_release -i -s 2>/dev/null`
version=`lsb_release -r -s 2>/dev/null`
targetSystem=""
targetVersion=""

if [ "$vendor" = Raspbian ]
then
    USER=pi
else
    USER=`id -un`
fi

#
# Allow overriding the destination directory on the Desktop
INSTALLMODE=user
OPTDESTDIR=""
PREFIX=""
CLEAN=0
SUSI_SERVER_USER=
CORAL=0
# default installation branch
# we use the same branch across repositories
# so if we build from susi_installer:master, we use the master branch of
# the other repos. And if we build from susi_installer:development, we use
# the development branch of the others.
# For other branches than master and development, we use the "development" branch
INSTALLBRANCH=master
if [ -d "$INSTALLERDIR/.git" ] ; then
    pushd "$INSTALLERDIR"
    CURRENTBRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENTBRANCH" = "master" ] ; then
        INSTALLBRANCH=master
    else
        INSTALLBRANCH=development
    fi
    popd
fi

# we save arguments in case we need to re-exec the installer after git clone
saved_args=""
if [ ! "$vendor" = Raspbian ]
then
    while [[ $# -gt 0 ]]
    do
        key="$1"

        case $key in
            --destdir)
                OPTDESTDIR="$2"
                # not saving arguments since we copy there/clone there before re-exec
                shift; shift
                ;;
            --system)
                INSTALLMODE=system
                saved_args="$saved_args --system"
                shift
                ;;
            --prefix)
                PREFIX="$2"
                saved_args="$saved_args --prefix \"$2\""
                shift ; shift
                ;;
            --clean)
                CLEAN=1
                saved_args="$saved_args --clean"
                shift
                ;;
            --use-sudo)
                SUDOCMD="sudo"
                saved_args="$saved_args --use-sudo"
                shift
                ;;
            --susi-server-user)
                SUSI_SERVER_USER="$2"
                saved_args="$saved_args --susi-server-user \"$2\""
                shift ; shift
                ;;
            --force-vendor)
                vendor="$2"
                saved_args="$saved_args --force-vendor \"$2\""
                shift ; shift
                ;;
            --force-version)
                version="$2"
                saved_args="$saved_args --force-version \"$2\""
                shift ; shift
                ;;
            --with-coral)
                CORAL=1
                saved_args="$saved_args --with-coral"
                shift
                ;;
            --help)
                cat <<'EOF'
SUSI.AI Installer

Possible options:
  --system         install system-wide
  --prefix <ARG>   (only with --system) install into <ARG>/lib/SUSI.AI
  --destdir <ARG>  (only without --system) install into <ARG>
                   defaults to $HOME/SUSI.AI
  --use-sudo       use sudo for installation of packages without asking
  --susi-server-user <ARG> (only with --system)
                   user under which the susi server is run, default: _susiserver
  --force-vendor
  --force-version  the installer uses `lsb_release` to determine the vendor and version
                   and has a limited set of allowed combinations that are supported.
                   These two options allow to override the detection using lsb_release.
                   Typical usage case are Debian/Ubuntu-based distributions that have
                   a different vendor name/version. Use with care. Currently supported
                   combinations:
                   - Debian: 9, 10, 11
                   - Ubuntu and LinuxMint: 18*, 19*, 20*

EOF
                exit 0
                shift
                ;;
            *)
                echo "Unknown option or argument: $key" >&2
                exit 1
        esac
    done
fi

case "$vendor" in
    Debian)
        # remove Debian .N version number
        targetSystem=debian
        targetVersion=${version%.*}
        # rewrite testing to 10
        if [ $targetVersion = "testing" ] ; then
            targetVersion=10
        fi
        case "$targetVersion" in
            9|10|11|unstable) ;;
            *) echo "Unsupported Debian version: $targetVersion" >&2 ; exit 1 ;;
        esac
        ;;
    Raspbian)
        # raspbian is Debian, so version numbers are the same - I hope
        targetSystem=raspi
        targetVersion=${version%.*}
        ;;
    Ubuntu)
        targetSystem=ubuntu
        targetVersion=$version
        case "$targetVersion" in
            18.*|19.*|20.*) ;;
            *) echo "Unsupported Ubuntu version: $targetVersion" >&2 ; exit 1 ;;
        esac
        ;;
    LinuxMint)
        targetSystem=mint
        targetVersion=$version
        case "$targetVersion" in
            18.*|18|19.*|19|20.*|20) ;;
            *) echo "Unsupported Linux Mint version: $targetVersion" >&2 ; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported distribution: $vendor" >&2
        exit 1
        ;;
esac


#
# Consistency checks:
# --prefix can only be given in with --system
# --destdir can only be given without --system
if [ $INSTALLMODE = system ] ; then
    if [ -n "$OPTDESTDIR" ] ; then
        echo "option --destdir cannot be used with --system" >&2
        exit 1
    fi
else
    if [ -n "$PREFIX" ] ; then
        echo "option --prefix can only be used with --system" >&2
        exit 1
    fi
    if [ -n "$SUSI_SERVER_USER" ] ; then
        echo "option --susi-server-user can only be used with --system" >&2
        exit 1
    fi
fi



# Dependencies of the packages or building
# we try to move as many pip packages to Debian packages
DEBDEPS="
  git openssl wget python3-pip sox libsox-fmt-all flac libasound2-plugins
  libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base
  vlc-plugin-video-splitter python3-cairo python3-flask flite
  default-jdk-headless pixz udisks2 python3-requests python3-requests-futures python3-service-identity
  python3-pyaudio python3-levenshtein python3-pafy python3-colorlog python3-psutil
  python3-setuptools python3-watson-developer-cloud ca-certificates
  python3-aiohttp python3-bs4 python3-mutagen python3-multidict python3-async-timeout
  python3-yarl
"

# If snowboy cannot be installed via pip we need to build it
SNOWBOYBUILDDEPS="
  perl libterm-readline-gnu-perl \
  i2c-tools python3-dev \
  swig libpulse-dev libasound2-dev \
  libatlas-base-dev
"

# CORAL dependencies
CORALDEPS="libc++1 libc++abi1 libunwind8 libwebpdemux2 python3-numpy python3-pil"

# python3-alsaaudio is not available on older distributions
# only install it on:
# - Debian buster and upwards
# - Ubuntu 19.04 and upwards
# - Linux Mint by now doesn't have python3-alsaaudio
if [[ ( $targetSystem = debian && ! $targetVersion = 9 ) \
      || \
      ( $targetSystem = ubuntu && ! $targetVersion = 18.04 && ! $targetVersion = 18.10 && ! $targetVersion = 19.01 ) \
      || \
      ( $targetSystem = raspi  && ! $targetVersion = 9 ) \
   ]]  ; then
  DEBDEPS="$DEBDEPS python3-alsaaudio"
fi

# we need hostapd and dnsmask for access point mode
# usbmount is needed to automount usb drives on susibian(raspbian lite)
if [ $targetSystem = raspi ] ; then
  DEBDEPS="$DEBDEPS hostapd dnsmasq usbmount"
fi

# add necessary dependencies for Coral device
if [ $CORAL = 1 ] ; then
    DEBDEPS="$DEBDEPS $CORALDEPS"
fi

# support external triggers in Travis builds,
TRIGGER_BRANCH=${TRIGGER_BRANCH:-""}
TRIGGER_SOURCE=${TRIGGER_SOURCE:-""}
if [[ ( -n $TRIGGER_SOURCE ) && ( -n $TRIGGER_BRANCH ) ]] ; then
    # we only accept triggers from fossasia
    TRIGGER_REPO=${TRIGGER_SOURCE#fossasia/}
    case "$TRIGGER_REPO" in
        susi_linux) SUSI_LINUX_BRANCH=$TRIGGER_BRANCH ;;
        susi_python) SUSI_PYTHON_BRANCH=$TRIGGER_BRANCH ;;
        *) echo "Unknown trigger source: $TRIGGER_SOURCE, ignoring it" ;;
    esac
fi
export SUSI_LINUX_BRANCH=${SUSI_LINUX_BRANCH:-$INSTALLBRANCH}
export SUSI_PYTHON_BRANCH=${SUSI_PYTHON_BRANCH:-$INSTALLBRANCH}
# if we are travis testing, then the correct branch is already
# checked out, so no need to do anything (see below).
# But if we git clone, we use this variable
export SUSI_INSTALLER_BRANCH=${SUSI_INSTALLER_BRANCH:-$INSTALLBRANCH}

#
# set up relevant paths and settings
if [ -z "$SUSI_SERVER_USER" ] ; then
    # on RPi this will be changed to "pi"
    SUSI_SERVER_USER=_susiserver
fi
if [ $INSTALLMODE = system ] ; then
    if [ -z "$PREFIX" ] ; then
        PREFIX="/usr/local"
    fi
    DESTDIR="$PREFIX/lib/SUSI.AI"
    BINDIR="$PREFIX/bin"
    # note that we do NOT expand $HOME here, since it must be replaced as is
    # in the common-script-start.in of susi_linux!
    WORKDIR='$HOME/.SUSI.AI'
else
    if [ $targetSystem = raspi ] ; then
        DESTDIR=/home/pi/SUSI.AI
        SUSI_SERVER_USER=pi
        CLEAN=1
    else
        if [ -z "$OPTDESTDIR" ] ; then
            DESTDIR="$HOME/SUSI.AI"
        else
            DESTDIR="$OPTDESTDIR"
        fi
    fi
    BINDIR="$DESTDIR/bin"
    WORKDIR="$DESTDIR"
fi



#
# This script works in two modes
# - when downloaded only by itself, it initiates the installation
#   by downloading the installer and starting it
# - when running the actual installer

if [ ! -d "raspi" ] ; then
    # we are in initial installer mode, where the user only downloaded
    # the install.sh script and runs it
    mkdir -p "$DESTDIR"
    cd "$DESTDIR"
    git clone https://github.com/fossasia/susi_installer.git
    cd susi_installer
    git checkout $SUSI_INSTALLER_BRANCH
    exec ./install.sh $saved_args
fi


#
# if the installer is download somewhere else then $DESTDIR, copy it over
if [ "$INSTALLERDIR" != "$DESTDIR/susi_installer" ] ; then
    echo "Copying installer to destination $DESTDIR ..."
    mkdir -p "$DESTDIR"
    if [ -d "$DESTDIR/susi_installer" ] ; then
        echo "SUSI Installer already present in $DESTDIR/susi_installer, please remove!"
        exit 1
    fi
    # we keep the current branch - eg on travis - and only copy the current status
    cp -a "$INSTALLERDIR" "$DESTDIR/susi_installer"
    # reset the INSTALLERDIR variable since we don't want to exec again
    INSTALLERDIR="$DESTDIR/susi_installer"
fi


# Set up default sudo mode
# on Raspi and in system mode, use sudo
# Otherwise leave empty so that user is asked whether to use it
if [ $targetSystem = raspi -o $INSTALLMODE = system ] ; then
    # on the RPi we always can run sudo
    # in system mode we expect root or sudo-able user to do it
    SUDOCMD=sudo
else
    SUDOCMD=${SUDOCMD:-""}
fi

#
# dpkg-architecture is in dpkg-dev, which might not be installed
HOSTARCH=`dpkg --print-architecture`
if [ $HOSTARCH = amd64 ] ; then
    HOSTARCHTRIPLE=x86_64-linux-gnu
elif [ $HOSTARCH = armhf ] ; then
    HOSTARCHTRIPLE=arm-linux-gnueabihf
elif [ $HOSTARCH = "i386" ] ; then
    HOSTARCHTRIPLE=i386-linux-gnu
else
    echo "Unknown host architecture: $HOSTARCH" >&2
    exit 1
fi

ask_for_sudo()
{
    # we only ask once for sudo command!
    if [ -z "$SUDOCMD" ] ; then
        if [[ $EUID -eq 0 ]]; then
            # root can always run sudo so we use it
            SUDOCMD="sudo"
            return
        fi
        echo -n "Do you want to use 'sudo' for this and following tasks? (Y/n): "
        REPLY=y
        read REPLY
        case $REPLY in
            n*|N*) SUDOCMD="echo Command to be run by root/via sudo: " ;;
            *) SUDOCMD="sudo" ; echo "Ok, running sudo!";;
        esac
    fi
}

check_debian_installation_status()
{
    # we need to be careful since multiarch means that if multiple arch versions
    # for one package are installed, a query without the ARchitecture returns all
    # of them
    stat=$(dpkg-query -W -f='${Status} ${Architecture}\n' $1 2>/dev/null || true)
    case "$stat" in
        *"install ok installed $HOSTARCH"*)
            return 0
            ;;
        *"install ok installed all"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

check_python_installation_status()
{
    printf %b "try:\n import $1\n exit(0)\nexcept ImportError:\n exit(1)"  | python3
}

install_debian_dependencies()
{
    # collect missing dependencies
    missing_packages=""
    for i in "$@" ; do
        if check_debian_installation_status $i ; then
            : all fine
        else
            missing_packages="$missing_packages $i"
        fi
    done
    if [ -z "$missing_packages" ] ; then
        # all packages are already installed, return happily
        return 0
    fi

    echo "The following packages are missing on your system:"
    echo "  $missing_packages"
    echo "Should we install them?"
    ask_for_sudo

    $SUDOCMD apt-get update
    $SUDOCMD -E apt-get install --no-install-recommends -y $missing_packages
    if [ $CLEAN = 1 ] ; then
        $SUDOCMD apt-get clean
    fi
}

install_pip_dependencies()
{
    reqfiles=$(ls susi_*/requirements.txt)
    reqpifiles=$(ls susi_*/requirements-rpi.txt)
    reqoptionalfiles=$(ls susi_*/requirements-optional.txt)

    echo "Installing Python Dependencies"
    if [ ! $targetSystem = raspi ] ; then
        PIPDEPS="`cat $reqfiles | grep -v '^\(\s*#\|\s*$\|--\)' | sed -e 's/=.*//' -e 's/>.*$//' -e 's/\s.*$//'`"

        # For now ignore the versioned deps
        missing_pips=""
        echo "Checking for available Python modules: "
        for i in $PIPDEPS ; do
            echo "checking for $i ..."
            # we are running under -e, so a not present packages would exit the script
            ret=`pip3 show $i || true`
            if [ -z "$ret" ] ; then
                missing_pips="$missing_pips $i"
            else
                :
                # check version
                # TODO ignore for now!
            fi
        done
        if [ -n "$missing_pips" ] ; then
            echo "The following Python packages are missing on your system:"
            echo "  $missing_pips"
            echo "Should we install them (using pip3)?"
            ask_for_sudo
        fi
    fi

    PIP=pip3
    if [ $CLEAN = 1 ] ; then
        PIP="pip3 --no-cache-dir"
    fi

    # we need to update pip, since pip 18 or so is too old and cannot work with --extra-index-url
    # properly
    $SUDOCMD $PIP install -U pip
    # wheel should not be necessary since we are not compiling anything?
    # $SUDOCMD $PIP install -U wheel
    for i in $reqfiles ; do
        $SUDOCMD $PIP install -r $i
    done
    for i in $reqoptionalfiles ; do
        $SUDOCMD $PIP install -r $i || true
    done
    if [ $targetSystem = raspi ] ; then
        for i in $reqpifiles ; do
            $SUDOCMD $PIP install -r $i
        done
    fi
}

function install_coral()
{
    cd "$DESTDIR"
    wget https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -O edgetpu_api.tar.gz --trust-server-names
    tar -xzf edgetpu_api.tar.gz
    cd edgetpu_api/
    yes | bash install.sh
    cd ..
    rm -rf edgetpu_api
    rm -f edgetpu_api.tar.gz
}


function install_snowboy()
{
    cd "$DESTDIR"
    install_debian_dependencies $SNOWBOYBUILDDEPS
    if [ ! -r v1.3.0.tar.gz ] ; then
        wget https://github.com/Kitt-AI/snowboy/archive/v1.3.0.tar.gz
    else
        echo "Reusing v1.3.0.tar.gz in $DESTDIR"
    fi
    tar -xf v1.3.0.tar.gz
    cd snowboy-1.3.0
    sed -i -e "s/version='1\.2\.0b1'/version='1.3.0'/" setup.py
    python3 setup.py build
    ask_for_sudo
    $SUDOCMD python3 setup.py install
    cd ..
    if [ $CLEAN = 1 ] ; then
        rm -f v1.3.0.tar.gz
    fi
}

function install_seeed_voicecard_driver()
{
    if arecord -l | grep -q voicecard
    then
        echo "ReSpeaker Mic Array driver was already installed."
        return 0
    fi
    echo "Installing Respeaker Mic Array drivers from source"
    cd "$DESTDIR"
    git clone https://github.com/respeaker/seeed-voicecard.git
    cd seeed-voicecard
    # remove libasound2-plugins from list of installed packages, it pulls in loads
    # and is not necessary
    sed -i -e 's/apt-get -y install \(.*\) libasound2-plugins/apt-get -y install \1/g' install.sh
    # This happens *ONLY* on the RPi, so we can do sudo!
    sudo ./install.sh
    # TODO Fix for crashes in pasound module that tear down susi-linux
    # src/hostapi/alsa/pa_linux_alsa.c:3641: PaAlsaStreamComponent_BeginPolling: Assertion `ret == self->nfds' failed
    # https://github.com/alexa/avs-device-sdk/issues/532
    # suggests that it has something to do with dsnoop
    # But that doesn't help a lot, just thinking about solutions.
    cd ..
    tar -czf ~/seeed-voicecard.tar.gz seeed-voicecard
    rm -rf seeed-voicecard
    if [ $CLEAN = 1 ] ; then
        sudo apt-get clean
    fi
}




####  Main  ####
cd "$DESTDIR"
mkdir -p $BINDIR
cp susi_installer/scripts/susi-config.in $BINDIR/susi-config
sed -i -e "s!@SUSI_WORKING_DIR@!$WORKDIR!g"  $BINDIR/susi-config
chmod +x $BINDIR/susi-config
# generate initial config.json
CFG="$WORKDIR/config.json"
DEVICENAME="Desktop Computer"
if [ $targetSystem = raspi ] ; then
    DEVICENAME="RaspberryPi"
fi
if [ ! -r "$CFG" ] ; then
  cat >"$CFG" <<EOF
{
  "Device": "$DEVICENAME",
  "WakeButton": "enabled",
  "default_stt": "google",
  "default_tts": "google",
  "data_base_dir": "$DESTDIR/susi_linux",
  "detection_bell_sound": "extras/detection-bell.wav",
  "problem_sound": "extras/problem.wav",
  "recognition_error_sound": "extras/recognition-error.wav",
  "flite_speech_file_path": "extras/cmu_us_slt.flitevox",
  "hotword_engine": "Snowboy",
  "usage_mode": "anonymous",
  "room_name": "office",
  "watson_tts_config": {
      "username": "", "password": ""
  }
}
EOF
fi


echo "Downloading: Susi Linux"
if [ ! -d "susi_linux" ]
then
    git clone https://github.com/fossasia/susi_linux.git
    cd susi_linux
    git checkout $SUSI_LINUX_BRANCH
    # link the vlcplayer and hwmixer
    ln -s ../susi_installer/pythonmods/hwmixer .
    ln -s ../susi_installer/pythonmods/vlcplayer .
    cd ..
else
    echo "WARNING: susi_linux directory already present, not cloning it!" >&2
fi
echo "Setting up wrapper scripts for susi_linux"
cd susi_linux/wrapper
for i in *.in ; do
    wr=`basename $i .in`
    cp $i $BINDIR/$wr
    sed -i -e "s!@INSTALL_DIR@!$DESTDIR/susi_linux!g" $BINDIR/$wr
    chmod ugo+x $BINDIR/$wr
done
cd ..
cp common-script-start.in common-script-start
sed -i -e "s!@SUSI_WORKING_DIR@!$WORKDIR!g" -e "s!@INSTALL_DIR@!$DESTDIR/susi_linux!g" common-script-start
cd ..


echo "Downloading: Susi Python API Wrapper"
if [ ! -d "susi_python" ]
then
    git clone https://github.com/fossasia/susi_python.git
    cd susi_python
    git checkout $SUSI_PYTHON_BRANCH
    cd ..
    ln -s ../susi_python/susi_python susi_linux/
else
    echo "WARNING: susi_python directory already present, not cloning it!" >&2
fi

echo "Downloading: Susi Skill Data"
if [ ! -d "susi_skill_data" ]
then
    git clone https://github.com/fossasia/susi_skill_data.git
else
    echo "WARNING: susi_skill_data directory already present, not cloning it!" >&2
fi

echo "Downloading: Susi server"
if [ ! -d susi_server ]
then
    git clone -b stable-dist --single-branch https://github.com/fossasia/susi_server.git
    # creating a local anonymous user with credentials:
    # Username: anonymous@susi.ai and password: password
    mkdir -p ./susi_server/data/settings/
    cat > ./susi_server/data/settings/authentication.json <<EOL
{
  "passwd_login:anonymous@susi.ai": {
    "salt": "i0Q9jnWLfRf4sRJN3svg",
    "id": "email:anonymous@susi.ai",
    "passwordHash": "+UarmkoElJhC6+RQdp7Cz1eYJ0Y0ebCCq8un4jYLpQ0=",
    "activated": true
  }
}
EOL
else
    echo "WARNING: susi_server directory already present, not cloning it!" >&2
fi

echo "Downloading: Susi.AI webclient"
if [ ! -d "susi.ai" ]
then
    git clone --depth 1 -b local-pages https://github.com/fossasia/susi.ai.git
    ln -s $PWD/susi.ai/static/* $PWD/susi_installer/raspi/controlserver/static/
    ln -s $PWD/susi.ai/index.html $PWD/susi_installer/raspi/controlserver/templates/
else
    echo "WARNING: susi.ai directory already present, not cloning it!" >&2
fi

echo "Installing required dependencies"
install_debian_dependencies $DEBDEPS
install_pip_dependencies
# in case that snowboy installation failed, build it from source
# also, make sure that we don't exit in case of not present snowboy
ret=`pip3 show snowboy || true`
if [ -z "$ret" ] ; then
    install_snowboy
fi

# function to update the latest vlc drivers which will allow it to play MRL of latest videos
# Only do this on old systems (stretch etc)
if [[ ( $targetSystem = debian && $targetVersion = 9 ) \
      || \
      ( $targetSystem = ubuntu && $targetVersion = 18.04 ) \
      || \
      ( $targetSystem = mint ) \
      || \
      ( $targetSystem = raspi && $targetVersion = 9 ) \
   ]]  ; then
    wget https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
    echo "Updating VLC drivers"
    ask_for_sudo
    if [ -d /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/ ] ; then
        $SUDOCMD mv youtube.lua /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/youtube.luac
    else
        echo "Cannot find directory /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/ - not updating youtube.lua" >&2
    fi
    rm -f youtube.lua
fi

#
# Add coral if selected
#
if [ $CORAL = 1 ] ; then
    install_coral
fi

#
# install seeed card driver only on RPi
if [ $targetSystem = raspi ]
then
    install_seeed_voicecard_driver
fi

# install Etherpad on RPi, including the depending modules
if [ $targetSystem = raspi ]
then
    echo "Downloading: Etherpad-lite"
    cd "$DESTDIR"
    if [ ! -d etherpad-lite ] ; then
        git clone --branch master https://github.com/ether/etherpad-lite.git
    else
        echo "WARNING: etherpad-lite directory already present, not cloning it!" >&2
    fi
    echo "Adding node.js repository"
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
    sudo apt-get install --no-install-recommends -y nodejs
    echo "Installing node modules for etherpad"
    cd etherpad-lite
    bin/installDeps.sh
    cd ..
    # systemd file is automatically installed using Deploy/auto... further below
fi

if [ ! -f "susi_linux/extras/cmu_us_slt.flitevox" ]
then
    echo "Downloading Speech Data for flite TTS"
    wget "http://www.festvox.org/flite/packed/flite-2.0/voices/cmu_us_slt.flitevox" -P susi_linux/extras
fi

if [ $targetSystem = raspi ]
then
    echo "Preparing USB automount"
    # systemd-udevd creates its own filesystem namespace, so mount is done, but it is not visible in the principal namespace.
    sudo mkdir /etc/systemd/system/systemd-udevd.service.d/
    echo -e "[Service]\nPrivateMounts=no" | sudo tee /etc/systemd/system/systemd-udevd.service.d/udev-service-override.conf
    # readonly mount for external USB drives
    sudo sed -i -e '/^MOUNTOPTIONS/ s/sync/ro/' /etc/usbmount/usbmount.conf
    sudo cp $INSTALLERDIR/raspi/media_daemon/01_create_skill /etc/usbmount/mount.d/
    sudo cp $INSTALLERDIR/raspi/media_daemon/01_remove_auto_skill /etc/usbmount/umount.d/

    echo "Installing RPi specific Systemd Rules"
    # TODO !!! we need to make the vlcplayer available to controlserver, as of now it does not find it
    sudo cp $INSTALLERDIR/raspi/systemd/ss-*.service /lib/systemd/system/
    sudo cp $INSTALLERDIR/raspi/systemd/ss-*.timer /lib/systemd/system/
    sudo systemctl enable ss-update-daemon.service
    sudo systemctl enable ss-update-daemon.timer
    sudo systemctl enable ss-factory-daemon.service
    sudo systemctl enable ss-controlserver.service
fi

echo "Updating Susi Linux Systemd service file"
cd "$DESTDIR"
cp 'susi_linux/systemd/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
cp 'susi_linux/systemd/ss-susi-linux.service.in' 'ss-susi-linux.service'
sed -i -e "s!@BINDIR@!$BINDIR!" ss-susi-linux.service
sed -i -e "s!@BINDIR@!$BINDIR!" 'ss-susi-linux@.service'
if [ $targetSystem = raspi -o $INSTALLMODE = user ] ; then
    # on RasPi, we install the system units into the system directories
    if [ $targetSystem = raspi ] ; then
        sudo cp 'ss-susi-linux@.service' /lib/systemd/system/
    else
        # Desktop in user mode
        mkdir -p $HOME/.config/systemd/user
        cp ss-susi-linux.service $HOME/.config/systemd/user/
    fi
else
    $SUDOCMD cp 'ss-susi-linux@.service' /lib/systemd/system/
    $SUDOCMD cp ss-susi-linux.service /usr/lib/systemd/user/
fi
rm 'ss-susi-linux@.service'
rm ss-susi-linux.service

echo "Installing Susi Linux Server Systemd service file"
cd "$DESTDIR"
cp 'susi_server/system-integration/systemd/ss-susi-server.service.in' 'ss-susi-server.service'
sed -i -e "s!@INSTALL_DIR@!$DESTDIR/susi_server!" ss-susi-server.service
sed -i -e "s!@SUSI_SERVER_USER@!$SUSI_SERVER_USER!" ss-susi-server.service
if [ $targetSystem = raspi -o $INSTALLMODE = user ] ; then
    # on RasPi, we install the system units into the system directories
    if [ $targetSystem = raspi ] ; then
        sudo cp 'ss-susi-server.service' /lib/systemd/system/
        sudo systemctl daemon-reload || true
    else
        # Desktop in user mode
        mkdir -p $HOME/.config/systemd/user
        # we need to filter out the User= line from user units!
        grep -v '^User=' ss-susi-server.service > $HOME/.config/systemd/user/ss-susi-server.service
        systemctl --user daemon-reload || true
    fi
else
    # susi-server does not support multi-user functionality by now
    # since data/log dirs are shared
    # $SUDOCMD cp ss-susi-server.service /usr/lib/systemd/user/
    #
    # add a new user for susi-server
    $SUDOCMD adduser --system \
            --quiet \
            --home /nonexistent \
            --no-create-home \
            --disabled-password \
            --group \
            --force-badname \
            $SUSI_SERVER_USER
    $SUDOCMD mkdir -p /var/lib/susi-server/data
    $SUDOCMD chown $SUSI_SERVER_USER:$SUSI_SERVER_USER /var/lib/susi-server/data
    $SUDOCMD ln -s /var/lib/susi-server/data susi_server/data
    $SUDOCMD cp ss-susi-server.service /lib/systemd/system/
    $SUDOCMD systemctl daemon-reload || true
fi
rm ss-susi-server.service

# enable the client service ONLY on Desktop, NOT on RPi
# On raspi we do other setups like reset folder etc
if [ $targetSystem = raspi ] ; then
    # make sure that the susi_server does not open the browser on startup
    sed -i -e 's/^local\.openBrowser\.enable\s*=.*/local.openBrowser.enable = false/' $DESTDIR/susi_server/conf/config.properties

    # update hostname to "susi" (and not raspberrypi)
    echo "susi" | sudo tee /etc/hostname

    # enable the server service unconditionally
    sudo systemctl enable ss-susi-server
    sudo systemctl enable ss-etherpad-lite

    # we need UTF8 char encoding, otherwise files with UTF8 names cannot
    # be dealt with in Python
    echo "Setting default locale to en_GB.UTF8"
    echo "LC_ALL=en_GB.UTF8" | sudo tee -a /etc/environment

    echo "Enabling the SSH access"
    sudo systemctl enable ssh

    # we need to restart udev once after reboot to get rw filesystems
    # see:
    # - https://github.com/raspberrypi/linux/issues/2497
    # - https://unix.stackexchange.com/questions/401394/udev-rule-triggers-but-any-run-command-fails
    # - https://www.raspberrypi.org/forums/viewtopic.php?t=210243
    # this is a recent change from udev somewhen in 2018?
    echo "Working around broken udev and ro file systems"
    sudo mkdir -p /etc/systemd/system
    sudo cp $INSTALLERDIR/raspi/media_daemon/udev-restart-after-boot.service /etc/systemd/system/udev-restart-after-boot.service
    sudo systemctl enable udev-restart-after-boot

    echo "Disable dhcpcd"
    sudo systemctl disable dhcpcd

    # link etherpad database file to $WORKDIR
    touch $WORKDIR/etherpad.db
    ln -s $WORKDIR/etherpad.db $DESTDIR/etherpad-lite/var/dirty.db

    # save susi_linux server data outside of server dir
    mkdir $WORKDIR/susi_server_data
    ln -s $WORKDIR/susi_server_data $DESTDIR/susi_server/data

    # create empty custom_skill file and make susi server read it
    mkdir -p $WORKDIR/susi_server_data/generic_skills/media_discovery
    touch $WORKDIR/susi_server_data/generic_skills/media_discovery/custom_skill.txt
    mkdir -p $WORKDIR/susi_server_data/settings
    echo "local.mode = true" > $WORKDIR/susi_server_data/settings/customized_config.properties

    cd "$DESTDIR"
    echo "Creating a backup folder for future factory_reset"
    tar -I 'pixz -p 2' -cf ../reset_folder.tar.xz --checkpoint=.1000 --exclude susi_server_data --exclude etherpad.db --exclude config.json .
    echo ""  # To add newline after tar's last checkpoint
    mv ../reset_folder.tar.xz susi_installer/raspi/factory_reset/reset_folder.tar.xz

    # Avahi has bug with IPv6, and make it fail to propage mDNS domain.
    sudo sed -i 's/use-ipv6=yes/use-ipv6=no/g' /etc/avahi/avahi-daemon.conf || true

    # install wlan config files: files with . in the name are *NOT* include
    # into the global /etc/network/interfaces file, so we can keep them there.
    echo "Installing ETH/WLAN device configuration files"
    sudo cp $INSTALLERDIR/raspi/access_point/interfaces.d/* /etc/network/interfaces.d/

    echo "Converting RasPi into an Access Point"
    sudo bash $INSTALLERDIR/raspi/access_point/wap.sh

    # install our home compiled package of libportaudio2
    sudo dpkg -i $INSTALLERDIR/raspi/debs/libportaudio2_19.6.0-1.1_armhf.deb
fi


#
# Final output
if [ ! $targetSystem = raspi ] ; then
    echo ""
    echo "SUSI AI has been installed into $DESTDIR."
    if [ $INSTALLMODE = user ] ; then
        echo "To start it once, type"
        echo "  systemctl --user start ss-susi-server"
        echo "  systemctl --user start ss-susi-linux"
        echo "To enable it permanently, use"
        echo "  systemctl --user enable ss-susi-server"
        echo "  systemctl --user enable ss-susi-linux"
    else
        echo "To start it once, type"
        echo "  sudo systemctl start ss-susi-server"
        echo "  systemctl --user start ss-susi-linux"
        echo "To enable it permanently, use"
        echo "  sudo systemctl enable ss-susi-server"
        echo "  systemctl --user enable ss-susi-linux"
        echo ""
        echo "There is also a ss-susi-linux@.service file which can be"
        echo "started/enabled for specific users via"
        echo "  sudo systemctl start/enable ss-susi-linux@USER"
        echo "instead of using the --user variant from above."
    fi
    echo ""
    echo "Enjoy."
else
    echo -e "SUSI is installed successfully!"
    echo -e "Please add $BINDIR to your PATH, then"
    echo -e "Run configuration script by 'susi-config set stt=<stt engine> tts=<tts engine> hotword=<snowboy> or pocketsphinx> wakebutton=<wake button>'"
    echo "For example, to configure SUSI as following: "
    echo -e "\t - Google for speech-to-text"
    echo -e "\t - Google for text-to-speech"
    echo -e "\t - Use snowboy for hot-word detection"
    echo -e "\t - Do not use GPIO for wake button"
    echo -e "susi-config set stt=google tts=google hotword=SnowBoy wakebutton=disable"
fi

# vim: set expandtab shiftwidth=4 softtabstop=4 smarttab:
