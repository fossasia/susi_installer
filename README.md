# Susi Installation

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/167b701c744841c5a05269d06b863732)](https://app.codacy.com/app/fossasia/susi_linux?utm_source=github.com&utm_medium=referral&utm_content=fossasia/susi_linux&utm_campaign=badger)
[![Build Status](https://travis-ci.org/fossasia/susi_linux.svg?branch=master)](https://travis-ci.org/fossasia/susi_linux)
[![Join the chat at https://gitter.im/fossasia/susi_hardware](https://badges.gitter.im/fossasia/susi_hardware.svg)](https://gitter.im/fossasia/susi_hardware?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Dependency Status](https://beta.gemnasium.com/badges/github.com/fossasia/susi_linux.svg)](https://beta.gemnasium.com/projects/github.com/fossasia/susi_linux)

SUSI AI on Desktop Linux and Raspberry Pi

This projects aims at installing the various components of SUSI.AI in your Raspberry Pi and Linux Distribution. It will enable you to bring Susi AI intelligence to all devices you may think like a Speaker, Car, Personal Desktop etc.

### Minimum Requirements

#### For making a smart speaker
* A hardware device capable to run Linux. Currently on Raspberry Pi 3 is supported. Other embedded computers, like BeagleBone Black, Orange Pi, will be supported in the future.
* A Debian based Linux Distribution. Tested on
    - Raspbian on Raspberry Pi 3
* A microphone for input. Currently the development team is using [ReSpeaker 2-Mics Pi HAT](https://www.seeedstudio.com/ReSpeaker-2-Mics-Pi-HAT-p-2874.html) for Raspberry Pi.
* A speaker for output. On development boards like Raspberry Pi, you can use a portable speaker that connects through
3.5mm audio jack. If you are using _ReSpeaker 2-Mics Pi HAT_, the speaker should be plugged to this board.

#### For using SUSI.AI on your desktop
* A desktop with any of the following linux distribution :
  - Ubuntu 18.04 or above
  - Debian stretch or above
  - Linux Mint 18.3
* A microphone for input

### Smart speaker assembly tutorial

How to assembly a smart speaker: [Video](https://www.youtube.com/watch?v=jAEmRvQLmc0)

### Installation Guide
* Rasberry Pi (smart speaker)
  - Download and flash the latest img file from: [Susibian.img](https://github.com/fossasia/susi_installer/releases) follow [setup guide.](docs/development_device_handout.md)
  - Manually setup using susi_installer - [Raspberry Pi setup guide.](docs/raspberry-pi_install.md)
* For installation on Ubuntu and other Debian based distributions, read [Ubuntu Setup Guide](docs/ubuntu_install.md)

### Configuring Smart Speaker
* Power on the device
* Connect your computer or mobile phone to the SUSI.AI hotspot using the password "password".
* Open http://10.0.0.1:5000 which will show you the set-up page as visible below:
![SUSI.AI Wifi Setup](docs/images/SUSI.AI-Wifi-Setup.png "SUSI.AI Wifi Setup")
* Put in your Wifi credentials. For an open network set an empty password. If The device should connect automatically to any open network, leave SSID and password empty.
* Click on "Reboot Smart Speaker"
* Wait for re-boot of the speaker, SUSI will say "SUSI has started" as soon it is ready.
* If you want to return to the installation process (i.e. to configure another network), you can reset the device by pushing and holding the button for at least 10 seconds.

### Configuring the Smart Speaker through the Android App
* Download the SUSI.AI android app: [Download Here](https://github.com/fossasia/susi_android/blob/apk/app-playStore-debug.apk)
* After Running the installation script , you'll have a RasPi in access point mode. With a Flask Server running at port 5000.
* You can use the mobile clients to configure the device automatically.<br>
<img src="docs/images/ios_app.gif" height="400px">


### Update Daemon

At any point of time, we may want to check if the current version of susi linux is updated. Hence we compare against the corresponding remote repository and we update it accordingly every time the raspberry Pi has started.
Use the following commands.
* `cd update_daemon/`
* `./update_check.sh`

### Factory Reset

To initiate the factory reset.<br/>
Press and hold the button on the Respeaker HAT to perform the following functions

| Button Press Duration| Action           | Description|
| -------------------- |:-------------|:-----|
| 7-15 seconds      | Access Point Mode | Smart Speaker is set to access point mode: Use this for setting up wifi again |
| 15-25 seconds      | Soft Factory Reset | Factory reset the device : User configuration is preserved|
| >25 seconds | Hard Factory Reset      |  Factory reset the device : User configuration is not preserved  |

