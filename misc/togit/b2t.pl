#!/usr/bin/env perl

use strict;
use warnings;

my @tags = ();
open my $gh, '-|', 'git', 'branch', '-a'
 or die "Can't get branches: $!\n";
while ( <$gh> ) {
  chomp;
  push @tags, $1, $2 if m{^\s*(tags/(\S+))};
}

while ( my ( $branch, $tag ) = splice @tags, 0, 2 ) {
  print "branch $branch -> tag $tag\n";
  system 'git', 'tag', $tag, $branch;
  system 'git', 'branch', '-r', '-d', $branch;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

