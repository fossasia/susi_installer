#!/bin/bash
# To be configured on auto boot-up

if [ "$EUID" -ne 0 ]
	then echo "Must be root"
	exit
fi

APPASS="password"
APSSID="SUSI.AI"


cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=10.0.0.2,10.0.0.5,255.255.255.0,12h
EOF

cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
hw_mode=g
channel=10
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=$APPASS
ssid=$APSSID
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
EOF

sed -i -- 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' /etc/default/hostapd

rm -f /etc/network/interfaces.d/wlan-client
cp /etc/network/interfaces.d/wlan.hostap /etc/network/interfaces.d/wlan-hostap

# systemctl unit setup
# these are dual to rwap.sh
systemctl enable hostapd
systemctl enable dnsmasq
systemctl disable ss-susi-linux@pi.service
systemctl disable ss-susi-login.service
systemctl enable ss-python-flask.service

# add server in the auto-boot up list
echo "All done! Rebooting"

reboot
