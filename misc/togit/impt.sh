#!/bin/bash

CWD=`pwd`
SVN2GIT=false
SVNURL="file://$CWD/svn/tapx"
AUTHORS=$CWD/../authors.txt
[ -f $AUTHORS ] || {
  echo "$AUTHORS doesn't exist"
  exit
}

rm -rf tapx.git
mkdir -p tapx.git
cd tapx.git
if $SVN2GIT; then
  git init
  svn2git $SVNURL authors=$AUTHORS
else
  git svn init --stdlayout $SVNURL
  git config svn.authorsfile $AUTHORS
  git config color.ui auto
  git svn fetch
  perl ../b2t.pl
  for b in `git branch -a`; do
    if [ $b != '* master' ]; then
      echo "Making $b local"
      git checkout $b
      git checkout -b $b
      git branch -rd $b
    fi
  done
  git checkout master
fi

# vim:ts=2:sw=2:sts=2:et:ft=sh

