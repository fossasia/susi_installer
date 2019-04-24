#!/bin/bash -e
#
# Target layout as with the developer-setup.md layou
# SUSI.AI/susi_installer
# SUSI.AI/susi_linux
# SUSI.AI/susi_api_wrapper
# SUSI.AI/susi_server
# SUSI.AI/susi_skill_data
# SUSI.AI/seeed_voicecard

SCRIPT_PATH=$(realpath "$0")
DIR_PATH=$(dirname "$SCRIPT_PATH")
# on the Raspi that should be /home/pi/SUSI.AI
BASE_PATH=$(realpath "$DIR_PATH/..")

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
    

add_debian_repo() {
    # Will add additional APT repo in the future
    sudo apt-get update
}

add_latest_drivers_vlc() {
    # function to update the latest vlc drivers which will allow it to play MRL of latest videos
    # Only do this on old systems (stretch etc)
    if [ $isBuster = 0 ] ; then
        wget -P /home/pi  https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
        sudo mv /home/pi/youtube.lua /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/vlc/lua/playlist/youtube.luac
    fi
}


install_debian_dependencies()
{
    sudo -E apt-get install -y git openssl wget python3-pip sox libsox-fmt-all flac \
    libportaudio2 libatlas3-base libpulse0 libasound2 vlc-bin vlc-plugin-base vlc-plugin-video-splitter \
    python3-cairo python3-flask flite default-jdk-headless pixz udisks2 \
    python3-requests python3-service-identity python3-pyaudio python3-levenshtein \
    python3-pafy python3-colorlog python3-watson-developer-cloud ca-certificates

    #
    # TODO
    # for development - building snowboy we probably need
    # if [ $isRaspi = 0 ]
    # then
    #     sudo -E apt-get install -y python3-setuptools perl libterm-readline-gnu-perl \
    #     i2c-tools libasound2-plugins python3-dev \
    #     swig libpulse-dev libasound2-dev \
    #     libatlas-base-dev

    # libatlas3-base is to provide libf77blas.so, liblapack_atlas.so for snowboy.
    # libportaudio2 is to provide libportaudio.so for PyAudio, which is snowboy's dependency.

    # Updating to the latest VLC drivers
    echo "Updating the latest Vlc Drivers"
    add_latest_drivers_vlc
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
    sudo ./install.sh
    cd ..
    #tar -czf ~/seeed-voicecard.tar.gz seeed-voicecard
    #rm -rf seeed-voicecard
}

function install_dependencies()
{
    if [ $isRaspi = 1 ]
    then
        install_seeed_voicecard_driver
    fi
}

function install_susi_server() {
    echo "To install SUSI Server"
    SUSI_SERVER_PATH="$BASE_PATH/susi_server"
    if [ ! -d "$SUSI_SERVER_PATH" ]
    then
        echo "Download susi_server_binary_latest.tar.gz"
        wget -P /tmp/ http://download.susi.ai/susi_server/susi_server_binary_latest.tar.gz
        tar -xzf /tmp/susi_server_binary_latest.tar.gz -C "/tmp"
        echo "Move susi_server from /tmp to $SUSI_SERVER_PATH"
        mv "/tmp/susi_server_binary_latest" "$SUSI_SERVER_PATH"
        rm "/tmp/susi_server_binary_latest.tar.gz" || true
    else
        echo "$SUSI_SERVER_PATH already exists."
    fi

    SKILL_DATA_PATH="$BASE_PATH/susi_skill_data"
    if [ ! -d "$SKILL_DATA_PATH" ]
    then
        git clone https://github.com/fossasia/susi_skill_data.git "$SKILL_DATA_PATH"
    fi
}

disable_ipv6_avahi() {
	# Avahi has bug with IPv6, and make it fail to propage mDNS domain.
	sudo sed -i 's/use-ipv6=yes/use-ipv6=no/g' /etc/avahi/avahi-daemon.conf || true
}


####  Main  ####
add_debian_repo

cd "$BASE_PATH"
echo "Downloading: Susi Linux"
if [ ! -d "susi_linux" ]
then
    git clone https://github.com/fossasia/susi_linux.git
    # TODO this needs to be removed after merge!!!
    cd susi_linux
    git checkout norbert/merged-stuff
    cd ..
fi
echo "Creating initial configuration for Susi Linux"
if [ ! -r "config.json" ]
then
    cp susi_linux/config.json .
    # fix data_base_dir
    sed -i -e 's!"data_base_dir": ".",!"data_base_dir": "susi_linux",!g' config.json
fi

echo "Downloading dependency: Susi Python API Wrapper"
if [ ! -d "susi_api_wrapper" ]
then
    git clone https://github.com/fossasia/susi_api_wrapper.git
    ln -s ../susi_api_wrapper/python_wrapper/susi_python susi_linux/
fi

echo "Installing required Debian Packages"
install_debian_dependencies
install_dependencies

echo "Installing Python Dependencies"
# We don't use "sudo -H pip3" here, so that pip3 cannot store cache.
# We want to discard cache to save disk space.
if [ $isBuster = 0 ]
then
  sudo pip3 install -U pip wheel
fi
sudo pip3 install -r susi_api_wrapper/python_wrapper/requirements.txt
# we need to distinguish here because on non-Raspi the server provided
# in the requirements-hw.txt are not usable for desktop systems
if [ $isRaspi = 1 ]
then
	sudo pip3 install -r susi_linux/requirements-hw.txt
else
	sudo pip3 install pip3 install speechRecognition==3.8.1 service_identity pocketsphinx==0.1.15 pyaudio json_config google_speech async_promises python-Levenshtein pyalsaaudio 'youtube-dl>2018' python-vlc pafy colorlog rx
fi
sudo pip3 install -r susi_linux/requirements-special.txt

echo "Downloading Speech Data for flite TTS"

if [ ! -f "susi_linux/extras/cmu_us_slt.flitevox" ]
then
    wget "http://www.festvox.org/flite/packed/flite-2.0/voices/cmu_us_slt.flitevox" -P susi_linux/extras
fi

if [ $isRaspi = 1 ]
then
    echo "Updating the Udev Rules"
    cd $DIR_PATH
    sudo ./raspi/media_daemon/media_udev_rule.sh
fi

echo "Cloning and building SUSI server"
install_susi_server

# TODO TODO 
# systemd files rework
if [ $isRaspi = 1 ]
    #
    #
    echo "Updating Systemd Rules"
    sudo bash $DIR_PATH/raspi/Deploy/auto_boot.sh
fi
echo "Updating Susi Linux Systemd service file"
cd "$BASE_PATH"
cp 'susi_linux/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
sed -i -e 's!@SUSI_WORKING_DIR@!/home/%i/SUSI.AI!' -e 's!@INSTALL_DIR@!/home/%i/SUSI.AI/susi_linux!' 'ss-susi-linux@.service'
sudo cp 'ss-susi-linux@.service' /lib/systemd/system/
# TODO
# we *SHOULD* move the ss-susi-server.service file to the susi-server distributions!!!!

if [ $isRaspi = 1 ]
then
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

    disable_ipv6_avahi

    # install wlan config files: files with . in the name are *NOT* include
    # into the global /etc/network/interfaces file, so we can keep them there.
    echo "Installing ETH/WLAN device configuration files"
    sudo cp $DIR_PATH/raspi/access_point/interfaces.d/* /etc/network/interfaces.d/

    echo "Converting RasPi into an Access Point"
    sudo bash $DIR_PATH/raspi/access_point/wap.sh
fi

echo -e "\033[0;92mSUSI is installed successfully!\033[0m"
echo -e "Run configuration script by 'python3 susi_linux/config_generator.py \033[0;32m<stt engine> \033[0;33m<tts engine> \033[0;34m<snowboy or pocketsphinx> \033[0;35m<wake button?>' \033[0m"
echo "For example, to configure SUSI as following: "
echo -e "\t \033[0;32m-Google for speech-to-text"
echo -e "\t \033[0;33m-Google for text-to-speech"
echo -e "\t \033[0;34m-Use snowboy for hot-word detection"
echo -e "\t \033[0;35m-Do not use GPIO for wake button\033[0m"
echo -e "python3 susi_linux/config_generator.py \033[0;32mgoogle \033[0;33mgoogle \033[0;34my \033[0;35mn \033[0m"
