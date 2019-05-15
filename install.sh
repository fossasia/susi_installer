#!/bin/bash -e
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
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

#
# TODO items
# - how would partial replacement of single packages with Debian packages work
# - RedHat and SuSE and Alpine and Mint and ... support ???


# Dependencies of the packages or building
# we try to move as many pip packages to Debian packages
DEBDEPS="
  git openssl wget python3-pip sox libsox-fmt-all flac
  libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base
  vlc-plugin-video-splitter python3-cairo python3-flask flite
  default-jdk-headless pixz udisks2 python3-requests python3-service-identity
  python3-pyaudio python3-levenshtein python3-pafy python3-colorlog
  python3-watson-developer-cloud ca-certificates
"

# If snowboy cannot be installed via pip we need to build it
SNOWBOYBUILDDEPS="
  python3-setuptools perl libterm-readline-gnu-perl \
  i2c-tools libasound2-plugins python3-dev \
  swig libpulse-dev libasound2-dev \
  libatlas-base-dev
"

#
# determine Debian/Ubuntu release - we don't support anything else at the moment
#                   Raspbian       Debian 9      Ubuntu          Debian 10
# lsb_release -i    Raspbian       Debian        Ubuntu          Debian
# lsb_release -r    9.N            9.N           14.04/16.04     10.N
#
# Ubuntu release: 14.04, 16.04, 18.04, 18.10, 19.04, ...
# Debian release: 9.N (2017/06 released, stretch, current stable, Raspbian), 10 (2019/0? released, buster), 11 (???)
# Raspbian release: 9.N (like Debian stretch)
#
# We classify systems into two categories:
# - isRaspi=0|1 -- only 1 on Raspbian)
# - isBuster=0|1 -- at least Debian 10 or Ubuntu 18.04
vendor=`lsb_release -i -s 2>/dev/null`
version=`lsb_release -r -s 2>/dev/null`
isRaspi=0
isBuster=0
case "$vendor" in
    Debian)
        # remove Debian .N version number
        version=${version%.*}
        case "$version" in
            9) isBuster=0 ;;
            10|11) isBuster=1 ;;
            *) echo "Unsupported Debian version: $version" >&2 ; exit 1 ;;
        esac
        ;;
    Raspbian)
        isRaspi=1
        ;;
    Ubuntu)
        case "$version" in
            18.*|19.*|20.*) isBuster=1 ;;
            *) echo "Unsupported Ubuntu version: $version" >&2 ; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported distribution: $vendor" >&2
        exit 1
        ;;
esac

if [ $isRaspi = 1 ]
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
if [ $isRaspi = 0 ]
then
    while [[ $# -gt 0 ]]
    do
        key="$1"

        case $key in
            --destdir)
                OPTDESTDIR="$2"
                shift; shift
                ;;
            --system)
                INSTALLMODE=system
                shift
                ;;
            --prefix)
                PREFIX="$2"
                shift ; shift
                ;;
            --clean)
                CLEAN=1
                shift
                ::
            --susi-server-user)
                SUSI_SERVER_USER="$2"
                shift ; shift
                ;;
            --help)
                cat <<'EOF'
SUSI.AI Installer

Possible options:
  --system         install system-wide
  --prefix <ARG>   (only with --system) install into <ARG>/lib/SUSI.AI
  --destdir <ARG>  (only without --system) install into <ARG>
                   defaults to $HOME/SUSI.AI
  --susi-server-user <ARG> (only with --system)
                   user under which the susi server is run, default: _susiserver

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


#
# in the pi-gen pipeline we get SUSI_REVISION (by default "development") passed
# into in the environment, but for Desktop installs we need to set it since we
# use it to checkout a branch of susi_linux
export SUSI_REVISION=${SUSI_REVISION:-"development"}

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
    if [ $isRaspi = 1 ] ; then
        DESTDIR=/home/pi/SUSI.AI
        SUSI_SERVER_USER=pi
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

if [ ! -d "raspi" ]
then
    # we are in initial installer mode, where the user only downloaded
    # the install.sh script and runs it
    mkdir -p "$DESTDIR"
    cd "$DESTDIR"
    git clone https://github.com/fossasia/susi_installer.git
    cd susi_installer
    # Start real installation
    sysarg=""
    if [ $INSTALLMODE = system ]
    then
        sysarg="--system --prefix $PREFIX"
    fi
    if [ $CLEAN = 1 ]
    then
        sysarg="--system --prefix $PREFIX --clean"
    fi
    exec ./install.sh $sysarg
fi



# Set up default sudo mode
# on Raspi and in system mode, use sudo
# Otherwise leave empty so that user is asked whether to use it
if [ $isRaspi = 1 -o $INSTALLMODE = system ] ; then
    # on the RPi we always can run sudo
    # in system mode we expect root or sudo-able user to do it
    SUDOCMD=sudo
else
    SUDOCMD=""
fi


SCRIPT_PATH=$(realpath "$0")
DIR_PATH=$(dirname "$SCRIPT_PATH")
# on the Raspi that should be $DESTDIR
BASE_PATH=$(realpath "$DIR_PATH/..")

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
    reqfiles="susi_python/requirements.txt susi_linux/requirements.txt"

    echo "Installing Python Dependencies"
    if [ $isRaspi = 0 ] ; then
        PIPDEPS="`cat $reqfiles | grep -v '^\(\s*#\|\s*$\|--\)' | sed -e 's/=.*//' -e 's/>.*$//' -e 's/\s.*$//'`"

        # For now ignore the versioned deps
        missing_pips=""
        echo "Checking for available Python modules: "
        for i in $PIPDEPS ; do
            echo "checking for $i ..."
            ret=`pip3 show $i`
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

    if [ $isRaspi = 1 ] ; then
        $SUDOCMD $PIP install -U pip
        $SUDOCMD $PIP install -U wheel
    fi

    $SUDOCMD $PIP install -r susi_python/requirements.txt
    $SUDOCMD $PIP install -r susi_linux/requirements.txt
    if [ $isRaspi = 1 ] ; then
        $SUDOCMD $PIP install -r susi_linux/requirements-rpi.txt
    fi
}

function install_snowboy()
{
    install_debian_dependencies $SNOWBOYBUILDDEPS
    if [ ! -r v1.3.0.tar.gz ] ; then
        wget https://github.com/Kitt-AI/snowboy/archive/v1.3.0.tar.gz
    else
        echo "Reusing v1.3.0.tar.gz in $BASE_PATH"
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
    # TODO: Modify this driver install script, so that it won't pull libasound-plugins,
    # which in turn, pull lot of video-related stuff.
    if arecord -l | grep -q voicecard
    then
        echo "ReSpeaker Mic Array driver was already installed."
        return 0
    fi
    echo "Installing Respeaker Mic Array drivers from source"
    cd "$BASE_PATH"
    git clone https://github.com/respeaker/seeed-voicecard.git
    cd seeed-voicecard
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
cd "$BASE_PATH"
echo "Downloading: Susi Linux"
if [ ! -d "susi_linux" ]
then
    git clone https://github.com/fossasia/susi_linux.git
    cd susi_linux
    # pi-gen used before "SUSI_REVISION" and *not* SUSI_BRANCH, or SUSI_PULL_REQUEST
    # we should simplify all these variables ...
    git checkout "$SUSI_REVISION"
    cd ..
else
    echo "WARNING: susi_linux directory already present, not cloning it!" >&2
fi
echo "Setting up wrapper scripts for susi_linux"
cd susi_linux/wrapper
mkdir -p $BINDIR
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
    # we don't use /tmp here since this allows for link attacks
    rm -f susi_server_binary_latest.tar.gz
    wget http://download.susi.ai/susi_server/susi_server_binary_latest.tar.gz
    tar -xzf susi_server_binary_latest.tar.gz
    mv susi_server_binary_latest susi_server
    rm susi_server_binary_latest.tar.gz
else
    echo "WARNING: susi_server directory already present, not cloning it!" >&2
fi


echo "Installing required dependencies"
install_debian_dependencies $DEBDEPS
install_pip_dependencies
# in case that snowboy installation failed, build it from source
ret=`pip3 show snowboy`
if [ -z "$ret" ] ; then
    install_snowboy
fi

# function to update the latest vlc drivers which will allow it to play MRL of latest videos
# Only do this on old systems (stretch etc)
if [ $isBuster = 0 ] ; then
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
# install seeed card driver only on RPi
if [ $isRaspi = 1 ]
then
    install_seeed_voicecard_driver
fi



if [ ! -f "susi_linux/extras/cmu_us_slt.flitevox" ]
then
    echo "Downloading Speech Data for flite TTS"
    wget "http://www.festvox.org/flite/packed/flite-2.0/voices/cmu_us_slt.flitevox" -P susi_linux/extras
fi

if [ $isRaspi = 1 ]
then
    echo "Updating the Udev Rules"
    cd $DIR_PATH
    sudo ./raspi/media_daemon/media_udev_rule.sh
fi

# systemd files rework
if [ $isRaspi = 1 ]
then
    echo "Installing RPi specific Systemd Rules"
    sudo bash $DIR_PATH/raspi/Deploy/auto_boot.sh
fi

echo "Updating Susi Linux Systemd service file"
cd "$BASE_PATH"
cp 'susi_linux/systemd/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
cp 'susi_linux/systemd/ss-susi-linux.service.in' 'ss-susi-linux.service'
sed -i -e "s!@BINDIR@!$BINDIR!" ss-susi-linux.service
sed -i -e "s!@BINDIR@!$BINDIR!" 'ss-susi-linux@.service'
if [ $isRaspi = 1 -o $INSTALLMODE = user ] ; then
    # on RasPi, we install the system units into the system directories
    if [ $isRaspi = 1 ] ; then
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
cd "$BASE_PATH"
cp 'susi_server/systemd/ss-susi-server.service.in' 'ss-susi-server.service'
sed -i -e "s!@INSTALL_DIR@!$BASE_PATH/susi_server!" ss-susi-server.service
sed -i -e "s!@SUSI_SERVER_USER@!$SUSI_SERVER_USER!" ss-susi-server.service
if [ $isRaspi = 1 -o $INSTALLMODE = user ] ; then
    # on RasPi, we install the system units into the system directories
    if [ $isRaspi = 1 ] ; then
        sudo cp 'ss-susi-server.service' /lib/systemd/system/
    else
        # Desktop in user mode
        mkdir -p $HOME/.config/systemd/user
        # we need to filter out the User= line from user units!
        grep -v '^User=' ss-susi-server.service > $HOME/.config/systemd/user/ss-susi-server.service
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
fi
rm ss-susi-server.service

# enable the client service ONLY on Desktop, NOT on RPi
# On raspi we do other setups like reset folder etc
if [ $isRaspi = 1 ] ; then
    # enable the server service unconditionally
    sudo systemctl enable ss-susi-server

    echo "Enabling the SSH access"
    sudo systemctl enable ssh

    echo "Disable dhcpcd"
    sudo systemctl disable dhcpcd

    cd "$BASE_PATH"
    echo "Creating a backup folder for future factory_reset"
    sudo rm -Rf .git
    tar --exclude-vcs -I 'pixz -p 2' -cf reset_folder.tar.xz --checkpoint=.1000 susi_linux susi_installer susi_server susi_skill_data susi_python
    echo ""  # To add newline after tar's last checkpoint
    mv reset_folder.tar.xz susi_installer/raspi/factory_reset/reset_folder.tar.xz

    # Avahi has bug with IPv6, and make it fail to propage mDNS domain.
    sudo sed -i 's/use-ipv6=yes/use-ipv6=no/g' /etc/avahi/avahi-daemon.conf || true

    # install wlan config files: files with . in the name are *NOT* include
    # into the global /etc/network/interfaces file, so we can keep them there.
    echo "Installing ETH/WLAN device configuration files"
    sudo cp $DIR_PATH/raspi/access_point/interfaces.d/* /etc/network/interfaces.d/

    echo "Converting RasPi into an Access Point"
    sudo bash $DIR_PATH/raspi/access_point/wap.sh
fi


#
# Final output
if [ $isRaspi = 0 ] ; then
    echo ""
    echo "SUSI AI has been installed into $BASE_PATH."
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
    echo -e "\033[0;92mSUSI is installed successfully!\033[0m"
    echo -e "Run configuration script by 'python3 susi_linux/config_generator.py \033[0;32m<stt engine> \033[0;33m<tts engine> \033[0;34m<snowboy or pocketsphinx> \033[0;35m<wake button?>' \033[0m"
    echo "For example, to configure SUSI as following: "
    echo -e "\t \033[0;32m-Google for speech-to-text"
    echo -e "\t \033[0;33m-Google for text-to-speech"
    echo -e "\t \033[0;34m-Use snowboy for hot-word detection"
    echo -e "\t \033[0;35m-Do not use GPIO for wake button\033[0m"
    echo -e "python3 susi_linux/config_generator.py \033[0;32mgoogle \033[0;33mgoogle \033[0;34my \033[0;35mn \033[0m"
fi

# vim: set expandtab shiftwidth=4 softtabstop=4 smarttab:
