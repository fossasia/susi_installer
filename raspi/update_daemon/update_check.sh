#!/bin/bash
# To be configured at bootup

cd /home/pi/SUSI.AI

update_repo() {
  if [ ! -d "$1" ] ; then
    echo "Unknown repository $1" >&2
    exit 1
  fi
  cd "$1"
  # get current branch name
  CURRENTBRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [ ! "x$CURRENTBRANCH" = "xmaster" ] ; then
    echo "Current branch of $1 is $CURRENTBRANCH, not master." >&2
    echo "Not updating!"
    return
  fi
  UPSTREAM=${2:-'@{u}'}
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

  if [ $CHECK = "Need-to-pull" ]
  then
    git pull
  fi
  cd ..
}

update_repo susi_linux
update_repo susi_python
update_repo susi_installer

#
# TODO we need to think about how to handle susi_server update!

