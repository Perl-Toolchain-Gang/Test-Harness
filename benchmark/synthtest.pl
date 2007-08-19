#!/usr/bin/perl

use strict;
use warnings;

my $count = shift || 1000;

print qq{print "1..$count\\n";\n};
print qq{print "ok \$_ some test or other\\n" for ( 1 .. $count );\n};

