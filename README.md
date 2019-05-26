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
  - Ubuntu 16.04/17.04/18.04
  - Linux Mint 18.3
* A microphone for input

### Smart speaker assembly tutorial

How to assembly a smart speaker: [Video](https://www.youtube.com/watch?v=jAEmRvQLmc0)

### Installation Guide
* Rasberry Pi
  - Download and flash the latest img file from: [Susibian.img](https://github.com/fossasia/susi_installer/releases)
  - Manually setup using susi_installer - [Raspberry Pi setup guide.](docs/raspberry-pi_install.md)
* For installation on Ubuntu and other Debian based distributions, read [Ubuntu Setup Guide](docs/ubuntu_install.md)

### Update Daemon

At any point of time, we may want to check if the current version of susi linux is updated. Hence we compare against the corresponding remote repository and we update it accordingly every time the raspberry Pi has started.
Use the following commands.
* `cd update_daemon/`
* `./update_check.sh`

### Factory Reset

To initiate the factory reset command.<br/>
Use the following commands.
* `cd factory_reset/`
* `chmod +x factory_reset.sh`
* `./factory_reset.sh`
