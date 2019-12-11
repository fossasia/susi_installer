#!/bin/bash -e
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

PROGS="git wget sox java vlc flac python3 pip3"

TRUSTPIP=0
CLEAN=0
BRANCH=development
RASPI=0
SUDOCMD=sudo
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --trust-pip)
            TRUSTPIP=1 ; shift ;;
        --clean)
            CLEAN=1 ; shift ;;
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
  --clean          Use --no-cache-dir with pip3

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
    pipversion=$(pip3 --version | sed -e 's/^pip //' -e 's/\..*$//' -e 's/ .*$//')
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
    PIP="pip3 --no-cache-dir"
fi

if [ $UPDATEPIP=1 ] ; then
    $SUDOCMD $PIP install -U pip
fi


reqs="
    susi_installer:requirements.txt
    susi_python:requirements.txt
    susi_linux:requirements.txt
    susi_installer:requirements-optional.txt
"
reqspi="
    susi_linux.git/requirements-rpi.txt
"


for i in $reqs ; do
    p=$(echo $i | sed -e s+:+/$BRANCH/+)
    wget -O $i https://raw.githubusercontent.com/fossasia/$p
done


for i in $reqfiles ; do
    $SUDOCMD $PIP install -r $i
done




######### UNFINISHED

echo "UNFINISHED BUSINESS" >&2
exit 1




#    ret=`pip3 show snowboy || true`
#    if [ -z "$ret" ] ; then
#        install_snowboy
#    fi

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
cp 'susi_linux/systemd/ss-susi-linux@.service.in' 'ss-susi-linux@.service'
cp 'susi_linux/systemd/ss-susi-linux.service.in' 'ss-susi-linux.service'
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
cp 'susi_server/systemd/ss-susi-server.service.in' 'ss-susi-server.service'
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
    $SUDOCMD cp ss-susi-server.service $systemdsystem
    $SUDOCMD systemctl daemon-reload || true
fi
rm ss-susi-server.service

sed -i -e 's/^local\.openBrowser\.enable\s*=.*/local.openBrowser.enable = false/' $DESTDIR/susi_server/conf/config.properties

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
