#! /bin/bash

clear

SCRIPT_PATH=$(realpath $0)
DIR_PATH=$(dirname $SCRIPT_PATH)

if [ -d "$DIR_PATH/../../../susi_server" ]
then
    cd $DIR_PATH
    # DEVNAME is exported from the udevd on the start/stop script
    python3 auto_skills.py "$DEVNAME"
else
    echo "Please download Skill Data"
fi 
