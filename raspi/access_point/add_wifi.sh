#! /bin/bash
SSID=""
PSK=""

if [ "$EUID" -ne 0 ]; then
  echo "Must be root"
  exit
fi

if [[ $# -gt 0 ]]; then
  SSID="$1"
fi

if [[ $# -gt 1 ]]; then
  PSK="$2"
fi

if [[ -z $PSK ]]; then
  echo "Adding open network $SSID"
  cat >> /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
network={
    ssid="$SSID"
    key_mgmt=NONE
}
EOF
  exit
fi

echo "Adding secure network $SSID"
cat >> /etc/wpa_supplicant/wpa_supplicant.conf <<EOF
network={
    ssid="$SSID"
    psk="$PSK"
}
EOF
