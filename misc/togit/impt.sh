#!/bin/bash

CWD=`pwd`
AUTHORS=$CWD/../authors.txt
[ -f $AUTHORS ] || {
  echo "$AUTHORS doesn't exist"
  exit
}

rm -rf tapx.git
mkdir -p tapx.git
cd tapx.git
git init
svn2git "file://$CWD/svn/tapx" authors=$AUTHORS

# vim:ts=2:sw=2:sts=2:et:ft=sh

