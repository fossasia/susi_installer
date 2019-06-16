#!/bin/bash
# To be configured at bootup

cd /home/pi/SUSI.AI

update_repo() {
  if [ ! -d "$1" ] ; then
    echo "Unknown repository $1" >&2
    exit 1
  fi
  cd "$1"
  UPSTREAM=${1:-'@{u}'}
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse "$UPSTREAM")
  BASE=$(git merge-base @ "$UPSTREAM")
  CHECK=''
  if [ $LOCAL = $REMOTE ]
  then
    echo "Up-to-date"
    CHECK='up-to-date'
  elif [ $LOCAL = $BASE ] 
  then
    echo "Need to pull"
    CHECK='Need-to-pull'
  else
    echo "Diverged"
  fi

  if [$CHECK = "Need-to-pull"]
  then
    git fetch UPSTREAM
    git merge UPSTREAM/master
  fi
  cd ..
}

update_repo susi_linux
update_repo susi_python
update_repo susi_installer

#
# TODO we need to think about how to handle susi_server update!

