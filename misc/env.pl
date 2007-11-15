#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
warn "# ", Data::Dumper->Dump([\@ARGV, \%ENV, $^X], [qw($ARGV $ENV $^X)]);
print "1..0 # SKIP just diagnostic\n";
