#! /bin/bash

mode="$1"

if [ -z "$mode" ] ; then
  echo "No mode given, not doing factory reset. Pass in 'soft' or 'hard'" >&2
  exit 1
fi

echo "running $mode factory reset process"

# stop running processes
# killall python3
killall java

# extract backup
echo "extracting reset folder"
mkdir /home/pi/SUSI.AI.NEW
tar -Ipixz -C /home/pi/SUSI.AI.NEW -xf /home/pi/SUSI.AI/susi_installer/raspi/factory_reset/reset_folder.tar.xz

# replace running version with backup
echo "replacing the current version with the original version"
mv /home/pi/SUSI.AI /home/pi/SUSI.AI.OLD
mv /home/pi/SUSI.AI.NEW /home/pi/SUSI.AI

# rescue the rescue dump before cleaning up
echo "rescuing the rescue folder"
mv /home/pi/SUSI.AI.OLD/susi_installer/raspi/factory_reset/reset_folder.tar.xz /home/pi/SUSI.AI/susi_installer/raspi/factory_reset/

# rescue config file 
# TODO we can provide options for full reset and partial reset
if [ $mode = soft ] ; then
  cp -a /home/pi/SUSI.AI.OLD/config.json /home/pi/SUSI.AI/
  cp -a /home/pi/SUSI.AI.OLD/etherpad.db /home/pi/SUSI.AI/
  cp -a /home/pi/SUSI.AI.OLD/susi_server_data /home/pi/SUSI.AI/
fi

# clean up
echo "cleaning up"
rm -rf /home/pi/SUSI.AI.OLD/

# prepare to run susi smart speaker as hot spot again
# here we undo the /home/pi/SUSI.AI/susi_linux/access_point/rwap.sh script
echo "restoring system definition files"
cp /etc/wpa_supplicant/wpa_supplicant.conf.bak /etc/wpa_supplicant/wpa_supplicant.conf
cp /etc/hostapd/hostapd.conf.bak /etc/hostapd/hostapd.conf
cp /etc/dhcpcd.conf.bak /etc/dhcpcd.conf
rm -f /etc/network/interfaces.d/wlan-client
cp /etc/network/interfaces.d/wlan.hostap /etc/network/interfaces.d/wlan-hostap

echo "enabling / disabling system services"
systemctl disable ss-susi-linux@pi.service
systemctl enable ss-python-flask.service
systemctl disable ss-susi-login.service

# restart
echo "reboot"
reboot
