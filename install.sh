#!/bin/bash
# SUSI.AI install wrapper for both the requirements and susi installer
# Copyright 2018-2020 Norbert Preining
#
set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [ $# -gt 0 ] ; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ] ; then
	echo "SUSI.AI installer"
	echo
	echo "This script runs installs the necessary requirements for SUSI.AI"
	echo "as well as the actual system, by calling the following two commands:"
	echo "   ./install-requirements.sh --system-install --with-deepspeech"
	echo "   ./install-susi.sh"
	echo
	echo "If you need different options, please call the scripts separately!"
	echo "See below for possible options."
	echo
	echo "Possible options for requirements installer:"
	./install-requirements.sh --help-only-options
	echo
	echo "Possible options for SUSI.AI system installer:"
	./install-susi.sh --help-only-options
	echo
	exit 0
    fi
fi

./install-requirements.sh --system-install --with-deepspeech
./install-susi.sh


# install-susi.sh options
# --destdir DIR
# --system
# --prefix ARG
# --clean
# --susi-server-user ARG
# --with-coral
# --dev

# install-requirements.sh options
# --trust-pip      Don't do version checks on pip3, trust it to be new enough
# --branch BRANCH  If no local checkouts are available, use the git remotes
#                   with branch BRANCH to get requirement files (default: development)
# --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
# --sudo-cmd CMD   Use CMD instead of the default sudo
# --system-install Try installing necessary programs, only supported for some distributions
# --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
# --with-deepspeech Install DeepSpeech and en-US model data
# --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
# --quiet          Silence pip on installation


read -p "Do you want to download languages for offline recognition?[y/n] " lang
echo 
if [[ $lang = y ]] ; then
    SR_LIB=$(python3 -c "import speech_recognition as sr, os.path as p; print(p.dirname(sr.__file__))")
    sudo mkdir "$SR_LIB/it-IT"
    sudo mkdir "$SR_LIB/temp"
    echo "Downloading Italian Language"
    sudo wget -O "$SR_LIB/temp/it-IT.tar.gz" 'https://sourceforge.net/projects/cmusphinx/files/Acoustic%20and%20Language%20Models/Italian/cmusphinx-it-5.2.tar.gz/download'
    sudo tar -zxf "$SR_LIB/temp/it-IT.tar.gz" --directory "$SR_LIB/temp"
    sudo mv "$SR_LIB/temp/cmusphinx-it-5.2/etc/voxforge_it_sphinx.lm" "$SR_LIB/temp/cmusphinx-it-5.2/etc/italian.lm"
    sudo sphinx_lm_convert -i "$SR_LIB/temp/cmusphinx-it-5.2/etc/italian.lm" -o "$SR_LIB/temp/cmusphinx-it-5.2/etc/italian.lm.bin"
    sudo mv "$SR_LIB/temp/cmusphinx-it-5.2/etc/italian.lm" "$SR_LIB/it-IT/italian.lm"
    sudo mv "$SR_LIB/temp/cmusphinx-it-5.2/etc/italian.lm.bin" "$SR_LIB/it-IT/italian.lm.bin"
    sudo mv "$SR_LIB/temp/cmusphinx-it-5.2/etc/voxforge_it_sphinx.dic" "$SR_LIB/it-IT/pronounciation-dictionary.dic"
    sudo mv -v "$SR_LIB/temp/cmusphinx-it-5.2/model_parameters/voxforge_it_sphinx.cd_cont_2000/" "$SR_LIB/it-IT/acoustic-model/"
    sudo rm -rf "$SR_LIB/temp"
    
fi

