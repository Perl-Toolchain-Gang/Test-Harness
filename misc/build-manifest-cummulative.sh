#!/bin/sh

mc="MANIFEST.CUMMULATIVE"
mct="MANIFEST.CUMMULATIVE.$$.TMP"

>$mct
git tag | while read tag ; do
  echo $tag
  git co $tag
  cat MANIFEST >> $mct
done
sort -u < $mct > $mc
rm -f $mct
git co master

# vim:ts=2:sw=2:sts=2:et:ft=sh

