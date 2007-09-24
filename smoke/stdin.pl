#!/usr/bin/perl

use strict;
use warnings;
use IO::Pty;

my $pty = IO::Pty->new;
open( STDIN, "<&" . $pty->slave->fileno() )
  || die "Couldn't reopen STDIN for reading, $!\n";

open( my $log, '>', '/tmp/isit' ) || die "That's fucked ($!)\n";
print $log -t STDIN ? "yes\n" : "no\n";
close $log;
