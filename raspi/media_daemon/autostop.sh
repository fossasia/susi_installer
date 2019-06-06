#! /bin/bash

SCRIPT_PATH=$(realpath $0)
DIR_PATH=$(dirname $SCRIPT_PATH)

cd $DIR_PATH/../../../susi_server/data/generic_skills/media_discovery/
 
sudo rm -f custom_skill.txt

exit 0

