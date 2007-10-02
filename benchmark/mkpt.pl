#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Path;

use constant DIR => 'pt';

# Make five sets of tests that exhibit differently pathological behavior.
# 
# fast:   100 scripts each of which outputs 3360 lines of TAP as quickly
#         as possible
# 
# fickle: 2500 scripts each of which quickly outputs a single line of TAP
# 
# greedy: 30 scripts each of which consumes about a second's worth of CPU
#         before outputting a single result
# 
# gross:  a single script that outputs 336000 lines of TAP as quickly
#         as possible
# 
# lazy:   30 scripts each of which sleeps for a second before outputting a
#         single line of TAP

my %make = (
    fast => {
        count => 100, test => <<'EOT'
print "1..3360\n";
print "ok $_ some test or other\n" for ( 1 .. 3360 );
EOT
    },
    fickle => {
        count => 2500, test => <<'EOT'
print "1..1\n";
print "ok 1 yes\n";
EOT
    },
    greedy => {
        count => 30, test => <<'EOT'
print "1..1\n";
for ( 1 .. 3200000 ) {
    delay();
}
print "ok 1 some test or other\n";
sub delay { }
EOT
    },
    gross => {
        count => 1, test => <<'EOT'
print "1..336000\n";
print "ok $_ some test or other\n" for ( 1 .. 336000 );
EOT
    },
    lazy => {
        count => 30, test => <<'EOT'
print "1..1\n";
sleep 1;
print "ok 1 some test or other\n";
EOT
    },
);

while ( my ( $name, $spec ) = each %make ) {
    my $dir = File::Spec->catdir( DIR, $name );
    mkpath($dir);
    print "$dir\n";
    for my $t ( 1 .. $spec->{count} ) {
        my $file
          = File::Spec->catfile( $dir, sprintf( "%s-%05d.t", $name, $t ) );
        open my $fh, '>', $file or die "Can't write $file ($!)\n";
        print $fh $spec->{test};
        close $fh;
    }
}
