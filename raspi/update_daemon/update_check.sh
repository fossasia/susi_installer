#!/bin/bash
# update script
# this is run via systemd time action on boot and once a week
# checks a set of repos for updates on a certain branch, and pulls them

cd /home/pi/SUSI.AI

update_repo() {
  if [ ! -d "$1" ] ; then
    echo "Unknown repository $1" >&2
    exit 1
  fi
  cd "$1"
  master="$2"
  if [ -z "$master" ] ; then
    # default branch is master
    master=master
  fi
  git fetch --all
  # get current branch name
  CURRENTBRANCH=$(git rev-parse --abbrev-ref HEAD)
  RET=0
  if [ ! "x$CURRENTBRANCH" = "x$master" ] ; then
    echo "Current branch of $1 is $CURRENTBRANCH, not $master." >&2
    echo "Not updating!"
    RET=0
  else
    UPSTREAM=${2:-'@{u}'}
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "$UPSTREAM")
    BASE=$(git merge-base @ "$UPSTREAM")
    CHECK=''
    if [ "$LOCAL" = "$REMOTE" ] ; then
      echo "Up-to-date"
    elif [ "$LOCAL" = "$BASE" ] ; then
      echo "Need to pull"
      git pull
      RET=1
    elif [ "$BASE" = "" ] ; then
      # the susi server case with a detached branch for the release
      echo "Need to reset to remote"
      git reset --hard origin/$CURRENTBRANCH
      RET=1
    else
      echo "Diverged"
    fi
  fi
  cd ..
  return $RET
}

do_reboot=0
update_repo susi_skill_data master || do_reboot=1
update_repo susi_server stable-dist || do_reboot=1
update_repo susi_linux master || do_reboot=1
update_repo susi_python master || do_reboot=1
update_repo susi_installer master || do_reboot=1

if [ $do_reboot = 1 ] ; then
  reboot
fi

