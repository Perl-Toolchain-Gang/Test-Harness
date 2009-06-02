#!/bin/bash
perl svn-reloc.pl < tapx.svn > tapx.svn.cvt || exit $?
mkdir -p svn
rm -rf svn/tapx tapx
svnadmin create svn/tapx
cat tapx.svn.cvt | svnadmin load svn/tapx || exit $?
svn co "file://`pwd`/svn/tapx"
