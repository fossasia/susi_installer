#!/bin/bash -e
#
# 
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
#   DESTDIR = ~/SUSI.AI
#   WORKDIR = ~/SUSI.AI
# System installation
#   DESTDIR = /usr/local/SUSI.AI
#   WORKDIR = ~/.SUSI.AI
#
# Layout withing DESTDIR
#   susi_installer
#   susi_linux
#   susi_api_wrapper
#   susi_server
#   susi_skill_data
#   seeed_voicecard

#
# TODO items
# - how to deal with susi_linux wrapper scripts?
#   in system mode install them into /usr/local/bin (link them?)
#   but in user mode? maybe link them to $DESTDIR/bin (= ~/SUSI.AI/bin) and ask user to add to PATH?
# - convert systemd unit files to use the wrapper scripts???
#   problem is in the case of user install
#   probably we need to put the full path into the unit file? - it is done in most service files like this!
# - how would partial replacement of single packages with Debian packages work
# - RedHat and SuSE and Alpine and Mint and ... support ???
# - should we clean up seeed_voicecard directory after installation of module?
#   this was done in the old installer (with tar.gz backup)

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
            16.*|17.*) ;;
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
            *)
                echo "Unknown option or argument: $key" >&2
                exit 1
        esac
    done
fi

####### TODO ##############
# FOR NOW WE DO NOT ALLOW SYSTEM MODE
# There are too many TODOs here in this file concerning system mode
#############################

if [ $INSTALLMODE = system ] ; then
    echo "Sorry, system installation mode is currently not supported. Aborting!" >&2
    exit 1
fi

#
# in the pi-gen pipeline we get SUSI_REVISION (by default "development") passed
# into in the environment, but for Desktop installs we need to set it since we
# use it to checkout a branch of susi_linux
export SUSI_REVISION=${SUSI_REVISION:-"development"}

#### TODO ###########
# for now as we are testing the separate installation mode, we have to override
# the SUSI_REVISION which is the branch/commit checked out of susi_linux
export SUSI_REVISION=norbert/separate-installation

#
# in system mode, either use /usr/local/SUSI.AI or the option --destdir
# if it was given
if [ -n "$OPTDESTDIR" ] ; then
    DESTDIR="$OPTDESTDIR"
else
    if [ $INSTALLMODE = system ] ; then
        DESTDIR=/usr/local/SUSI.AI
    else
        if [ $isRaspi = 1 ] ; then
            DESTDIR=/home/pi/SUSI.AI
        else
            DESTDIR=$HOME/SUSI.AI
        fi
    fi
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
    # TODO needs to be removed after merge
    git checkout desktop
    # Start real installation
    sysarg=""
    if [ $INSTALLMODE = system ]
    then
        sysarg="--system"
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

HOSTARCH=`dpkg-architecture -qDEB_HOST_ARCH`

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
    DEBDEPS="
  git openssl wget python3-pip sox libsox-fmt-all flac
  libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base
  vlc-plugin-video-splitter python3-cairo python3-flask flite
  default-jdk-headless pixz udisks2 python3-requests python3-service-identity
  python3-pyaudio python3-levenshtein python3-pafy python3-colorlog
  python3-watson-developer-cloud ca-certificates
"
    
    SNOWBOYBUILDDEPS="
  python3-setuptools perl libterm-readline-gnu-perl \
  i2c-tools libasound2-plugins python3-dev \
  swig libpulse-dev libasound2-dev \
  libatlas-base-dev
"

    ALLDEPS="$DEBDEPS"
    if [ $isRaspi = 0 ] ; then
        ALLDEPS="$ALLDEPS $SNOWBOYBUILDDEPS"
    fi

    # collect missing dependencies
    missing_packages=""
    for i in $ALLDEPS ; do
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
    $SUDOCMD -E apt-get install -y $missing_packages
}

install_pip_dependencies()
{
    echo "Installing Python Dependencies"
    if [ $isRaspi = 0 ] ; then
        # TODO dynamically generate this list from the requirement files?!?
        PIPDEPS="async_promises colorlog geocoder google_speech json_config pafy 
                 pyalsaaudio pyaudio python-Levenshtein python-vlc
                 rx service_identity snowboy watson-developer-cloud 
                 websocket_server youtube-dl"

        # not used here
        PIPDEPSRPI="RPi.GPIO spidev"

        declare -A PIPDEPSVERS
        PIPDEPSVERS["speechRecognition"]="==3.8.1"
        PIPDEPSVERS["pocketsphinx"]="==0.1.15"
        PIPDEPSVERS["youtube-dl"]=">2018"
        PIPDEPSVERS["requests"]=">=2.13.0"


        # First check which of the packages are available
        alldeps="$PIPDEPS ${!PIPDEPSVERS[@]}"

        # For now ignore the versioned deps
        missing_pips=""
        echo "Checking for available Python modules: "
        for i in $PIPDEPS ${!PIPDEPSVERS[@]} ; do
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
            $SUDOCMD pip3 install $missing_pips
        fi
    else
        # we are on the RPi now
        $SUDOCMD pip3 install -U pip wheel
        $SUDOCMD pip3 install -r susi_api_wrapper/python_wrapper/requirements.txt
        $SUDOCMD pip3 install -r susi_linux/requirements-hw.txt
        $SUDOCMD pip3 install -r susi_linux/requirements-special.txt
    fi
}

function install_snowboy()
{
    ret=`pip3 show snowboy`
    if [ -z "$ret" ] ; then
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
    #tar -czf ~/seeed-voicecard.tar.gz seeed-voicecard
    #rm -rf seeed-voicecard
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
echo "Creating initial configuration for Susi Linux"
if [ ! -r "config.json" ]
then
    cp susi_linux/config.json .
    # fix data_base_dir
    if [ $INSTALLMODE = user ] ; then
        sed -i -e 's!"data_base_dir": ".",!"data_base_dir": "susi_linux",!g' config.json
    else
        : 
        # do nothing here, system installation mode is not supported by now
        # we need to push the initial config.json configuration into the
        # starter scripts (see debian packaging scripts!)
    fi
else
    echo "WARNING: config.json already present, not overwriting it!" >&2
fi

echo "Downloading: Susi Python API Wrapper"
if [ ! -d "susi_api_wrapper" ]
then
    git clone https://github.com/fossasia/susi_api_wrapper.git
    ln -s ../susi_api_wrapper/python_wrapper/susi_python susi_linux/
else
    echo "WARNING: susi_api_wrapper directory already present, not cloning it!" >&2
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
install_debian_dependencies
if [ $isRaspi = 0 ] ; then
    # the repo of fossasia does not provide snowboy for all pythons .. install it
    install_snowboy
fi
install_pip_dependencies
# function to update the latest vlc drivers which will allow it to play MRL of latest videos
# Only do this on old systems (stretch etc)
if [ $isBuster = 0 ] ; then
    wget https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
    echo "Updating VLC drivers"
    ask_for_sudo
    $SUDOCMD mv youtube.lua /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/vlc/lua/playlist/youtube.luac
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
    #
    #
    echo "Installing RPi specific Systemd Rules"
    sudo bash $DIR_PATH/raspi/Deploy/auto_boot.sh
fi

echo "Updating Susi Linux Systemd service file"
cd "$BASE_PATH"
cp 'susi_linux/systemd/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
cp 'susi_linux/systemd/ss-susi-linux.service.in' 'ss-susi-linux.service'
if [ $isRaspi = 1 -o $INSTALLMODE = user ] ; then
    sed -i -e "s!@SUSI_WORKING_DIR@!$BASE_PATH!" -e "s!@INSTALL_DIR@!$BASE_PATH/susi_linux!" ss-susi-linux.service
    sed -i -e "s!@SUSI_WORKING_DIR@!$BASE_PATH!" -e "s!@INSTALL_DIR@!$BASE_PATH/susi_linux!" 'ss-susi-linux@.service'
    # on RasPi, we install the system units into the system directories
    if [ $isRaspi = 1 ] ; then
        sudo cp 'ss-susi-linux@.service' /lib/systemd/system/
    else
        # Desktop in user mode
        mkdir -p $HOME/.config/systemd/user
        cp ss-susi-linux.service $HOME/.config/systemd/user/
    fi
else
    # System mode ... not supported by now ... but that is the correct definition
    # %h cannot be expanded in system services
    # because if it is on NIS or so it is not available
    # at boot time - another systemd stupidity ...
    # But it can be expanded in the user service file
    sed -i -e "s!@SUSI_WORKING_DIR@!%h/.SUSI.AI!" -e "s!@INSTALL_DIR@!$BASE_PATH/susi_linux!" ss-susi-linux.service
    sed -i -e "s!@SUSI_WORKING_DIR@!/home/%i/.SUSI.AI!" -e "s!@INSTALL_DIR@!$BASE_PATH/susi_linux!" 'ss-susi-linux@.service'
    $SUDOCMD cp 'ss-susi-linux@.service' /lib/systemd/system/
    $SUDOCMD cp ss-susi-linux.service /usr/lib/systemd/user/
fi
rm 'ss-susi-linux@.service'
rm ss-susi-linux.service

echo "Installing Susi Linux Server Systemd service file"
cd "$BASE_PATH"
cp 'susi_server/systemd/ss-susi-server@.service.in' 'ss-susi-server@.service'
cp 'susi_server/systemd/ss-susi-server.service.in' 'ss-susi-server.service'
if [ $isRaspi = 1 -o $INSTALLMODE = user ] ; then
    sed -i -e "s!@INSTALL_DIR@!$BASE_PATH/susi_server!" ss-susi-server.service
    sed -i -e "s!@INSTALL_DIR@!$BASE_PATH/susi_server!" 'ss-susi-server@.service'
    # on RasPi, we install the system units into the system directories
    if [ $isRaspi = 1 ] ; then
        sudo cp 'ss-susi-server@.service' /lib/systemd/system/
    else
        # Desktop in user mode
        mkdir -p $HOME/.config/systemd/user
        cp ss-susi-server.service $HOME/.config/systemd/user/
    fi
else
    # System mode ... not supported by now ... but that is the correct definition
    sed -i -e "s!@INSTALL_DIR@!$BASE_PATH/susi_server!" ss-susi-linux.service
    sed -i -e "s!@INSTALL_DIR@!$BASE_PATH/susi_server!" 'ss-susi-linux@.service'
    $SUDOCMD cp 'ss-susi-linux@.service' /lib/systemd/system/
    $SUDOCMD cp ss-susi-linux.service /usr/lib/systemd/user/
fi
rm 'ss-susi-server@.service'
rm ss-susi-server.service

# enable the client service ONLY on Desktop, NOT on RPi
# On raspi we do other setups like reset folder etc
if [ $isRaspi = 1 ] ; then
    # enable the server service unconditionally
    sudo systemd enable ss-susi-server@pi

    echo "Enabling the SSH access"
    sudo systemctl enable ssh

    echo "Disable dhcpcd"
    sudo systemctl disable dhcpcd

    cd "$BASE_PATH"
    echo "Creating a backup folder for future factory_reset"
    sudo rm -Rf .git
    tar --exclude-vcs -I 'pixz -p 2' -cf reset_folder.tar.xz --checkpoint=.1000 susi_linux susi_installer susi_server susi_skill_data susi_api_wrapper
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
    if [ $INSTALLMODE = user ] ; then
        echo ""
        echo "SUSI AI has been installed into $BASE_PATH."
        echo "To start it once, type"
        echo "  systemctl --user start ss-susi-server"
        echo "  systemctl --user start ss-susi-linux"
        echo "To enable it permanently, use"
        echo "  systemctl --user enable ss-susi-server"
        echo "  systemctl --user enable ss-susi-linux"
        echo ""
        echo "Enjoy."
    else
        echo "STILL NOT ACTIVATED AND NOT WORKING"
        echo "WE NEED MORE TESTING HERE!!!!"
    fi
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
