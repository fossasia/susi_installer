#!/bin/bash
# SUSI.AI Smart Assistant Installer
#
# Copyright 2018-2020 Norbert Preining
#
set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

INSTALLERDIR=$(dirname $(realpath "$0"))

#
# Target layout as with the developer-setup.md layout
#
# Two modes of installation: "user" and "system"
# On the RPi we *always* run in user mode and use sudo
# On the Desktop in user mode, no root rights are necessary
#
# Installation directory defaults
# User installation
#   DESTDIR = ~/.susi.ai                --destdir can override this
#                                       on RPi: ~/SUSI.AI
#   BINDIR  = $DESTDIR/bin
#   WORKDIR = $DESTDIR
# System installation
#   DESTDIR = $prefix/lib/SUSI.AI       --prefix can be given
#   BINDIR  = $prefix/bin
#   WORKDIR = ~/.susi.ai
#
#   In system mode the susi-server starts as user $SUSI_SERVER_USER
#   which defaults to _susiserver and can be configured via --susi-server-user
#
# Layout withing DESTDIR
#   pythonmods (containing links to susi_installer/pythonmods/* and susi_python)
#   susi_installer
#   susi_linux
#   susi_python
#   susi_server
#   susi_skill_data
#   seeed_voicecard
#   etherpad-lite (for raspi)
# Contents of WORKDIR
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
        Manjaro)   targetSystem=manjaro  ;;
        Arch)      targetSystem=arch  ;;
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
# default installation branch
# we use the same branch across repositories
# so if we build from susi_installer:master, we use the master branch of
# the other repos. And if we build from susi_installer:development, we use
# the development branch of the others.
# For other branches than master and development, we use the "development" branch
INSTALLBRANCH=master
SERVERINSTALLBRANCH=stable-dist
if [ -d "$INSTALLERDIR/.git" ] ; then
    pushd "$INSTALLERDIR" >/dev/null
    CURRENTBRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENTBRANCH" = "master" ] ; then
        INSTALLBRANCH=master
        SERVERINSTALLBRANCH=stable-dist
    else
        INSTALLBRANCH=development
        SERVERINSTALLBRANCH=dev-dist
    fi
    popd >/dev/null
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
                SERVERINSTALLBRANCH=dev-dist
                saved_args="$saved_args --dev"
                shift
                ;;
            --help)
                cat <<'EOF'
SUSI.AI Installer

Possible options:
  --system         install system-wide (requires root permissions)
  --prefix <ARG>   (only with --system) install into <ARG>/lib/SUSI.AI
  --destdir <ARG>  (only without --system) install into <ARG>
                   defaults to $HOME/.susi.ai
  --susi-server-user <ARG> (only with --system)
                   user under which the susi server is run, default: _susiserver
  --dev            use development branch
  --with-coral     install support libraries for the Coral device (Raspberry)

EOF
                exit 0
                ;;
            --help-only-options)
                cat <<'EOF'
  --system         install system-wide (requires root permissions)
  --prefix <ARG>   (only with --system) install into <ARG>/lib/SUSI.AI
  --destdir <ARG>  (only without --system) install into <ARG>
                   defaults to $HOME/.susi.ai
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
export SUSI_SERVER_BRANCH=${SUSI_SERVER_BRANCH:-$SERVERINSTALLBRANCH}
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
    PYTHONMODDIR="$DESTDIR/pythonmods"
    # note that we do NOT expand $HOME here, since it must be replaced as is
    # in the common-script-start.in of susi_linux!
    WORKDIR='$HOME/.susi.ai'
else
    if [ $targetSystem = raspi ] ; then
        DESTDIR=/home/pi/SUSI.AI
        SUSI_SERVER_USER=pi
        CLEAN=1
    else
        if [ -z "$OPTDESTDIR" ] ; then
            DESTDIR="$HOME/.susi.ai"
        else
            DESTDIR="$OPTDESTDIR"
        fi
    fi
    BINDIR="$DESTDIR/bin"
    WORKDIR="$DESTDIR"
    PYTHONMODDIR="$DESTDIR/pythonmods"
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
    sudo apt-get install --no-install-recommends -y $CORALDEPS
    wget https://dl.google.com/coral/edgetpu_api/edgetpu_api_latest.tar.gz -O edgetpu_api.tar.gz --trust-server-names
    tar -xzf edgetpu_api.tar.gz
    cd edgetpu_api/
    yes | bash install.sh
    cd ..
    rm -rf edgetpu_api
    rm -f edgetpu_api.tar.gz
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
    sudo bash ./install.sh
    cd ..
    tar -czf ~/seeed-voicecard.tar.gz seeed-voicecard
    rm -rf seeed-voicecard
    if [ $CLEAN = 1 ] ; then
        sudo apt-get clean
    fi
}

prog_available() {
    if ! [ -x "$(command -v $1)" ]; then
        return 1
    fi
}



####  Main  ####
cd "$DESTDIR"

echo "Downloading: Susi Linux"
if [ ! -d "susi_linux" ]
then
    git clone https://github.com/fossasia/susi_linux.git
    cd susi_linux
    git checkout $SUSI_LINUX_BRANCH
    cd ..
else
    echo "WARNING: susi_linux directory already present, not cloning it!" >&2
fi
echo "Setting up scripts for susi_linux"
mkdir -p $BINDIR
for i in susi_linux/system-integration/scripts/* ; do
    cp $i $BINDIR/
    # shouldn't be necessary, but for safety
    chmod ugo+x "$BINDIR/$(basename $i)"
done


echo "Downloading: Susi Python API Wrapper"
if [ ! -d "susi_python" ]
then
    git clone https://github.com/fossasia/susi_python.git
    cd susi_python
    git checkout $SUSI_PYTHON_BRANCH
    cd ..
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
    git clone -b $SUSI_SERVER_BRANCH --single-branch https://github.com/fossasia/susi_server.git
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
echo "Setting up scripts for susi_server"
mkdir -p $BINDIR
for i in susi_server/system-integration/scripts/* ; do
    cp $i $BINDIR/
    # shouldn't be necessary, but for safety
    chmod ugo+x "$BINDIR/$(basename $i)"
done

echo "Downloading: Susi.AI webclient"
if [ ! -d "susi.ai" ]
then
    git clone --depth 1 -b local-pages https://github.com/fossasia/susi.ai.git
    #ln -s $PWD/susi.ai/static/* $PWD/susi_installer/raspi/controlserver/static/
    #ln -s $PWD/susi.ai/index.html $PWD/susi_installer/raspi/controlserver/templates/
    echo "WARNING: SUSI.AI Web client is installed but currently not served!"
else
    echo "WARNING: susi.ai directory already present, not cloning it!" >&2
fi


echo "Setting up Python modules"
mkdir -p "$PYTHONMODDIR"
for i in hwmixer susi_config vlcplayer ; do
    ln -s ../susi_installer/pythonmods/$i "$PYTHONMODDIR/$i"
done
ln -s ../susi_python/susi_python "$PYTHONMODDIR/susi_python"
ln -s ../susi_linux/susi_linux "$PYTHONMODDIR/susi_linux"


echo "Initializing SUSI config"
mkdir -p $BINDIR
for i in susi_installer/system-integration/scripts/* ; do
    cp $i $BINDIR/
    # shouldn't be necessary, but for safety
    chmod ugo+x "$BINDIR/$(basename $i)"
done

DEVICENAME="Desktop Computer"
if [ $targetSystem = raspi ] ; then
    DEVICENAME="RaspberryPi"
fi
# generate initial configuration file for susi-config
$BINDIR/susi-config set \
    path.base="." \
    device="$DEVICENAME" \
    wakebutton=enable \
    tts=flite \
    stt=deepspeech-local \
    path.sound.detection=susi_linux/extras/detection-bell.wav \
    path.sound.problem=susi_linux/extras/problem.wav \
    path.sound.error.recognition=susi_linux/extras/recognition-error.wav \
    path.sound.error.timeout=susi_linux/extras/error-tada.wav \
    path.flite_speech=susi_linux/extras/cmu_us_slt.flitevox \
    hotword.engine=Snowboy \
    susi.mode=anonymous \
    roomname=office \
    watson.tts.user="" \
    watson.tts.pass=""

# we have to override wakebutton and devicename
# since susi-config cannot detect the right hardware
# during image build via qemu
if [ $targetSystem = raspi ] ; then
    export PYTHONPATH=$PYTHONMODDIR:
    python3 - <<EOF
from susi_config import SusiConfig
susicfg = SusiConfig()
susicfg.config['wakebutton'] = 'enabled'
susicfg.config['device'] = 'RaspberryPi'
EOF
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
        if [ -w /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/youtube.luac ] ; then
            cp youtube.lua /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/youtube.luac || true
            rm youtube.lua
        else
            echo "Cannot update /usr/lib/$HOSTARCHTRIPLE/vlc/lua/playlist/youtube.luac."
        fi
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

# install Etherpad, including the depending modules
# on RPi install nodejs, on Desktop systems only install Etherpad if node/nodejs is installed
NODEJS=""
if prog_available node ; then
    NODEJS=node
elif prog_available nodejs ; then
    NODEJS=nodejs
else
    echo "Neither node nor nodejs available, not installing EtherPad!" >&2
fi
if [ -n "$NODEJS" ] ; then
    echo "Downloading: Etherpad-lite"
    cd "$DESTDIR/susi_server/data"
    if [ ! -d etherpad-lite ] ; then
        mkdir etherpad-lite
        # get latest release of etherpad
        epurl=$(curl --silent https://api.github.com/repos/ether/etherpad-lite/releases/latest | grep -Po '"tarball_url": "\K.*?(?=")')
        curl -sL "$epurl" | tar -xzf - --strip-components=1 -C etherpad-lite
        # git clone --branch master https://github.com/ether/etherpad-lite.git
    else
        echo "WARNING: etherpad-lite directory already present, not cloning it!" >&2
    fi
    echo "Installing node modules for etherpad"
    cd etherpad-lite
    bin/installDeps.sh
    cd ..
    # systemd file is automatically installed using Deploy/auto... further below
fi

cd "$DESTDIR"
if [ ! -f "susi_linux/extras/cmu_us_slt.flitevox" ]
then
    echo "Downloading Speech Data for flite TTS"
    wget "http://www.festvox.org/flite/packed/flite-2.0/voices/cmu_us_slt.flitevox" -P susi_linux/extras
fi

if [ $targetSystem = raspi ]
then
    # make sure that wifi is turned on on boot
    # recent raspbian kernel default to disable that via
    # systemd-rfkill.service
    echo "Ensuring WIFI is turned on on first boot"
    if [ -d /var/lib/systemd/rfkill ] ; then
        for i in /var/lib/systemd/rfkill/*':wlan' ; do
            echo "0" | sudo tee $i
        done
    fi
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
    sudo cp $INSTALLERDIR/raspi/systemd/ss-*.service /lib/systemd/system
    sudo cp $INSTALLERDIR/raspi/systemd/ss-*.timer /lib/systemd/system
    sudo systemctl enable ss-update-daemon.service
    sudo systemctl enable ss-update-daemon.timer
    sudo systemctl enable ss-factory-daemon.service
    sudo systemctl enable ss-controlserver.service
fi

echo "Updating Susi Linux Systemd service file"
if [ $targetSystem = raspi ] ; then
    sudo $BINDIR/susi-config install systemd raspi
    sudo systemctl daemon-reload || true
elif [ $INSTALLMODE = user ] ; then
    $BINDIR/susi-config install systemd $INSTALLMODE
    systemctl --user daemon-reload || true
else
    # system mode
    # we expect to be able to run as root
    # susi-server does not support multi-user functionality by now
    # since data/log dirs are shared
    # cp ss-susi-server.service $systemduser
    #
    # add a new user for susi-server
    useradd -r -d /nonexistent $SUSI_SERVER_USER
    mkdir -p /var/lib/susi-server/data
    chown $SUSI_SERVER_USER:$SUSI_SERVER_USER /var/lib/susi-server/data
    ln -s /var/lib/susi-server/data susi_server/data
    $BINDIR/susi-config install systemd $INSTALLMODE
    systemctl daemon-reload || true
fi

sed -i -e 's/^local\.openBrowser\.enable\s*=.*/local.openBrowser.enable = false/' $DESTDIR/susi_server/conf/config.properties


echo "Installing Susi Desktop files"
if [ $targetSystem = raspi ] ; then
    sudo $BINDIR/susi-config install desktop raspi
elif [ $INSTALLMODE = user ] ; then
    $BINDIR/susi-config install desktop $INSTALLMODE
else #system mode
    $BINDIR/susi-config install desktop $INSTALLMODE
fi

if [ $INSTALLMODE = user ] ; then
    echo "Adding SUSI bin directory to shell"
    $BINDIR/susi-config install shell
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
    # we default to local (flite/deepspeech) so we can start the client right ahead
    sudo systemctl enable ss-susi-linux@pi.service

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

    # save susi_linux server data outside of server dir
    mv $DESTDIR/susi_server/data $WORKDIR/susi_server_data
    #rm -rf $DESTDIR/susi_server/data
    #mkdir $WORKDIR/susi_server_data
    ln -s $WORKDIR/susi_server_data $DESTDIR/susi_server/data

    # create empty custom_skill file and make susi server read it
    mkdir -p $WORKDIR/susi_server_data/generic_skills/media_discovery
    touch $WORKDIR/susi_server_data/generic_skills/media_discovery/custom_skill.txt
    mkdir -p $WORKDIR/susi_server_data/settings
    echo "local.mode = true" > $WORKDIR/susi_server_data/settings/customized_config.properties

    cd "$DESTDIR"
    echo "Creating a backup folder for future factory_reset"
    tar -I 'pixz -p 2' -cf ../reset_folder.tar.xz --checkpoint=.1000 --exclude susi_server_data .
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
        if [ -d "$DESTDIR/susi_server/data/etherpad-lite" ] ; then
        echo "  systemctl --user start ss-etherpad-lite"
        fi
        echo "To enable it permanently, use"
        echo "  systemctl --user enable ss-susi-server"
        echo "  systemctl --user enable ss-susi-linux"
        if [ -d "$DESTDIR/susi_server/data/etherpad-lite" ] ; then
        echo "  systemctl --user enable ss-etherpad-lite"
        fi
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
    echo -e "Run configuration script by 'susi-config set stt=<stt engine> tts=<tts engine> hotword.engine=<snowboy> or pocketsphinx> wakebutton=<wake button>'"
    echo "For example, to configure SUSI as following: "
    echo -e "\t - Google for speech-to-text"
    echo -e "\t - Google for text-to-speech"
    echo -e "\t - Use snowboy for hot-word detection"
    echo -e "\t - Do not use GPIO for wake button"
    echo -e "susi-config set stt=google tts=google hotword.engine=SnowBoy wakebutton=disable"
fi

# vim: set expandtab shiftwidth=4 softtabstop=4 smarttab:
