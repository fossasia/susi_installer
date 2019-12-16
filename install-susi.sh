#!/bin/bash
# SUSI.AI Smart Assistant Installer
#
# Copyright 2018-2019 Norbert Preining
#
set -euo pipefail
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
#
#                   Raspbian       Debian 9      Ubuntu          Debian 10  Mint
# lsb_release -i    Raspbian       Debian        Ubuntu          Debian     LinuxMint
# lsb_release -r    9.N            9.N           14.04/16.04     10.N       18.2
#
# Ubuntu release: 14.04, 16.04, 18.04, 18.10, 19.04, ...
# Debian release: 9.N (2017/06 released, stretch, current stable, Raspbian), 10 (2019/0? released, buster), 11 (???)
# Raspbian release: 9.N, 10.N (like Debian stretch)
# Linux Mint: 18.*, 19.*, 18, 19
#
# We classify systems according to distribution and version
# - targetSystem is the string that is contained in /etc/os-release as ID=....
#   unfortunately that differs from the lsb_release -i output ...
version=""
targetSystem="unknown"
targetVersion=""
if [ -x "$(command -v lsb_release)" ]; then
    vendor=`lsb_release -i -s 2>/dev/null`
    version=`lsb_release -r -s 2>/dev/null`
    case "$vendor" in
        Debian)    targetSystem=debian  ;;
        Raspbian)  targetSystem=raspi   ;;
        Ubuntu)    targetSystem=ubuntu  ;;
        LinuxMint) targetSystem=linuxmint ;;
        CentOS)    targetSystem=centos  ;;
        Fedora)    targetSystem=fedora  ;;
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


if [ "$targetSystem" = raspi ]
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
SUDOCMD=sudo
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
if [ ! "$targetSystem" = raspi ]
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
            --sudo-cmd)
                SUDOCMD="$2"
                saved_args="$saved_args --sudo-cmd \"$2\""
                shift ; shift
                ;;
            --susi-server-user)
                SUSI_SERVER_USER="$2"
                saved_args="$saved_args --susi-server-user \"$2\""
                shift ; shift
                ;;
            --with-coral)
                CORAL=1
                saved_args="$saved_args --with-coral"
                shift
                ;;
            --dev)
                INSTALLBRANCH=development
                saved_args="$saved_args --dev"
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
  --sudo-cmd <ARG> command to run programs that need root privileges
  --susi-server-user <ARG> (only with --system)
                   user under which the susi server is run, default: _susiserver
  --dev            use development branch
  --with-coral     install support libraries for the Coral device (Raspberry)

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

case "$targetSystem" in
    debian)
        # remove Debian .N version number
        targetVersion=${version%.*}
        # rewrite testing to 10
        if [ $targetVersion = "testing" ] ; then
            targetVersion=11
        fi
        case "$targetVersion" in
            9|10|11|unstable) ;;
            *) echo "Unrecognized or old Debian version, expect problems: $targetVersion" >&2 ;;
        esac
        ;;
    raspi)
        # raspbian is Debian, so version numbers are the same - I hope
        targetVersion=${version%.*}
        ;;
    ubuntu)
        targetVersion=$version
        case "$targetVersion" in
            18.*|19.*|20.*) ;;
            *) echo "Unrecognized or old Ubuntu version, expect problems: $targetVersion" >&2 ;;
        esac
        ;;
    linuxmint)
        targetVersion=$version
        case "$targetVersion" in
            18.*|18|19.*|19|20.*|20) ;;
            *) echo "Unrecognized or old Linux Mint version, expect problems: $targetVersion" >&2 ;;
        esac
        ;;
    fedora|centos)
        : "no details available about Fedora for now"
        ;;
    *)
        targetVersion=$version
        echo "Unrecognized distribution: $targetSystem" >&2
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
    exec ./install-susi.sh $saved_args
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


# only called for raspi, so debian style
function install_coral()
{
    cd "$DESTDIR"
    CORALDEPS="libc++1 libc++abi1 libunwind8 libwebpdemux2 python3-numpy python3-pil"
    $SUDOCMD apt-get install --no-install-recommends -y $CORALDEPS
    wget https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -O edgetpu_api.tar.gz --trust-server-names
    tar -xzf edgetpu_api.tar.gz
    cd edgetpu_api/
    yes | bash install.sh
    cd ..
    rm -rf edgetpu_api
    rm -f edgetpu_api.tar.gz
}


# only called for raspi, so debian style
function install_snowboy()
{
    cd "$DESTDIR"
    SNOWBOYBUILDDEPS="perl libterm-readline-gnu-perl i2c-tools python3-dev swig libpulse-dev
        libasound2-dev libatlas-base-dev"
    $SUDOCMD apt-get install --no-install-recommends -y $SNOWBOYBUILDDEPS
    if [ ! -r v1.3.0.tar.gz ] ; then
        wget https://github.com/Kitt-AI/snowboy/archive/v1.3.0.tar.gz
    else
        echo "Reusing v1.3.0.tar.gz in $DESTDIR"
    fi
    tar -xf v1.3.0.tar.gz
    cd snowboy-1.3.0
    sed -i -e "s/version='1\.2\.0b1'/version='1.3.0'/" setup.py
    python3 setup.py build
    $SUDOCMD python3 setup.py install
    cd ..
    if [ $CLEAN = 1 ] ; then
        rm -f v1.3.0.tar.gz
    fi
}

# only called for raspi, so debian style
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

# function to update the latest vlc drivers which will allow it to play MRL of latest videos
# Only do this on old systems (stretch etc)
if [[ ( $targetSystem = debian && $targetVersion = 9 ) \
      || \
      ( $targetSystem = ubuntu && $targetVersion = 18.04 ) \
      || \
      ( $targetSystem = linuxmint ) \
      || \
      ( $targetSystem = raspi && $targetVersion = 9 ) \
   ]]  ; then
    HOSTARCH=`dpkg --print-architecture`
    if [ $HOSTARCH = amd64 ] ; then
        HOSTARCHTRIPLE=x86_64-linux-gnu
    elif [ $HOSTARCH = armhf ] ; then
        HOSTARCHTRIPLE=arm-linux-gnueabihf
    elif [ $HOSTARCH = "i386" ] ; then
        HOSTARCHTRIPLE=i386-linux-gnu
    else
        echo "Unknown host architecture: $HOSTARCH" >&2
        echo "Cannot update vlc player youtube plugin" >&2
        return
    fi
    wget https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
    echo "Updating VLC drivers"
    if [ -d /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/ ] ; then
        $SUDOCMD mv youtube.lua /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/youtube.luac
    else
        echo "Cannot find directory /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/ - not updating youtube.lua" >&2
    fi
    rm -f youtube.lua
fi


#
# install seeed card driver only on RPi
if [ $targetSystem = raspi ]
then
    #
    # Add coral if selected
    #
    if [ $CORAL = 1 ] ; then
        install_coral
    fi
    # install seeed voicecard driver
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

#
# Use pkg-config to get correct systemd install path
#   system units: pkg-config systemd --variable=systemdsystemunitdir
#                 on Debian: /lib/systemd/system
#   user units:   pkg-config systemd --variable=systemduserunitdir
#                 on Debian: /usr/lib/systemd/user
# but install path into $HOME are fixed I guess
systemdsystem=""
systemduser=""
if [ -x "$(command -v pkg-config)" ]
then
    systemdsystem=$(pkg-config systemd --variable=systemdsystemunitdir 2>/dev/null)
    systemduser=$(pkg-config systemd --variable=systemduserunitdir 2>/dev/null)
fi
if [ -z "$systemdsystem" ] ; then
    systemdsystem=/lib/systemd/system
fi
if [ -z "$systemduser" ] ; then
    systemduser=/usr/lib/systemd/user
fi
systemdhomeuser=$HOME/.config/systemd/user


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
    sudo cp $INSTALLERDIR/raspi/systemd/ss-*.service $systemdsystem
    sudo cp $INSTALLERDIR/raspi/systemd/ss-*.timer $systemdsystem
    sudo systemctl enable ss-update-daemon.service
    sudo systemctl enable ss-update-daemon.timer
    sudo systemctl enable ss-factory-daemon.service
    sudo systemctl enable ss-controlserver.service
fi

echo "Updating Susi Linux Systemd service file"
cd "$DESTDIR"
if [ -d susi_linux/systemd ] ; then
    cp 'susi_linux/systemd/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
    cp 'susi_linux/systemd/ss-susi-linux.service.in' 'ss-susi-linux.service'
elif [ -d susi_linux/system-integration/systemd ] ; then
    cp 'susi_linux/system-integration/systemd/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
    cp 'susi_linux/system-integration/systemd/ss-susi-linux.service.in' 'ss-susi-linux.service'
fi
sed -i -e "s!@BINDIR@!$BINDIR!" ss-susi-linux.service
sed -i -e "s!@BINDIR@!$BINDIR!" 'ss-susi-linux@.service'
if [ $targetSystem = raspi -o $INSTALLMODE = user ] ; then
    # on RasPi, we install the system units into the system directories
    if [ $targetSystem = raspi ] ; then
        sudo cp 'ss-susi-linux@.service' $systemdsystem
    else
        # Desktop in user mode
        mkdir -p $systemdhomeuser
        cp ss-susi-linux.service $systemdhomeuser
    fi
else
    $SUDOCMD cp 'ss-susi-linux@.service' $systemdsystem
    $SUDOCMD cp ss-susi-linux.service $systemduser
fi
rm 'ss-susi-linux@.service'
rm ss-susi-linux.service

echo "Installing Susi Linux Server Systemd service file"
cd "$DESTDIR"
if [ -d susi_server/systemd ] ; then
    cp 'susi_server/systemd/ss-susi-server.service.in' 'ss-susi-server.service'
elif [ -d susi_server/system-integration/systemd ] ; then
    cp 'susi_server/system-integration/systemd/ss-susi-server.service.in' 'ss-susi-server.service'
fi
sed -i -e "s!@INSTALL_DIR@!$DESTDIR/susi_server!" ss-susi-server.service
sed -i -e "s!@SUSI_SERVER_USER@!$SUSI_SERVER_USER!" ss-susi-server.service
if [ $targetSystem = raspi -o $INSTALLMODE = user ] ; then
    # on RasPi, we install the system units into the system directories
    if [ $targetSystem = raspi ] ; then
        sudo cp 'ss-susi-server.service' $systemdsystem
        sudo systemctl daemon-reload || true
    else
        # Desktop in user mode
        mkdir -p $systemdhomeuser
        # we need to filter out the User= line from user units!
        grep -v '^User=' ss-susi-server.service > $systemdhomeuser/ss-susi-server.service
        systemctl --user daemon-reload || true
    fi
else
    # susi-server does not support multi-user functionality by now
    # since data/log dirs are shared
    # $SUDOCMD cp ss-susi-server.service $systemduser
    #
    # add a new user for susi-server
    $SUDOCMD useradd -r -d /nonexistent $SUSI_SERVER_USER
    $SUDOCMD mkdir -p /var/lib/susi-server/data
    $SUDOCMD chown $SUSI_SERVER_USER:$SUSI_SERVER_USER /var/lib/susi-server/data
    $SUDOCMD ln -s /var/lib/susi-server/data susi_server/data
    $SUDOCMD cp ss-susi-server.service $systemdsystem
    $SUDOCMD systemctl daemon-reload || true
fi
rm ss-susi-server.service

sed -i -e 's/^local\.openBrowser\.enable\s*=.*/local.openBrowser.enable = false/' $DESTDIR/susi_server/conf/config.properties

echo "Installing Susi Desktop files"
cd "$DESTDIR"
# susi server
if [ -d susi_server/desktop ] ; then
    cp 'susi_server/desktop/ss-susi-server.desktop.in' 'ss-susi-server.desktop'
elif [ -d susi_server/system-integration/desktop ] ; then
    cp 'susi_server/system-integration/desktop/ss-susi-server.desktop.in' 'ss-susi-server.desktop'
fi
if [ -r ss-susi-server.desktop ] ; then
    sed -i -e "s!@INSTALL_DIR@!$DESTDIR/susi_server!" ss-susi-server.desktop
fi

# susi linux
sldd=""
if [ -d susi_linux/desktop ] ; then
    sldd=susi_linux/desktop
elif [ -d susi_server/system-integration/desktop ] ; then
    sldd=susi_linux/system-integration/desktop
fi
for i in $sldd/*.desktop.in ; do
    if [ -f "$i" ] ; then
        deskfile=${i%.in}
        cp $i $deskfile
        sed -i -e "s!@BINDIR@!$BINDIR!" $deskfile
    fi
done
if [ $targetSystem = raspi -o $INSTALLMODE = user ] ; then
    mkdir -p "$HOME/.local/share/applications"
    if [ -r ss-susi-server.desktop ] ; then
        cp ss-susi-server.desktop "$HOME/.local/share/applications"
        rm ss-susi-server.desktop
    fi
    for i in $sldd/*.desktop ; do
        if [ -f "$i" ] ; then
            cp $i "$HOME/.local/share/applications"
        fi
        rm $i
    done
else
    sudo mkdir -p "$PREFIX/share/applications"
    if [ -r ss-susi-server.desktop ] ; then
        sudo cp ss-susi-server.desktop "$PREFIX/share/applications"
        rm ss-susi-server.desktop
    fi
    for i in $sldd/*.desktop ; do
        if [ -f "$i" ] ; then
            sudo cp $i "$PREFIX/share/applications"
        fi
        rm $i
    done
fi



# enable the client service ONLY on Desktop, NOT on RPi
# On raspi we do other setups like reset folder etc
if [ $targetSystem = raspi ] ; then
    # make sure that the susi_server does not open the browser on startup

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
