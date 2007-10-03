#!/usr/bin/perl -wT

use strict;

use File::Spec;
use File::Find;
use Test::More;
use constant DISTRIBUTION => 'TAP::Parser';

sub file_to_pm {
    my ( $dir, $file ) = @_;
    $file =~ s/\.pm$// || return;    # we only care about .pm files
    $file =~ s{\\}{/}g;              # to make win32 happy
    $dir  =~ s{\\}{/}g;              # to make win32 happy
    $file =~ s/^$dir//;
    my $_package = join '::' => grep $_ => File::Spec->splitdir($file);

    # untaint that puppy!
    my ($package) = $_package =~ /^([\w]+(?:::[\w]+)*)$/;
    return DISTRIBUTION eq $package ? () : $package;
}

BEGIN {
    my $dir = 'lib';

    my @classes;
    find(
        {   no_chdir => 1,      # keeps it taint safe
            wanted   => sub {
                -f && /\.pm$/
                  && push @classes => file_to_pm( $dir, $File::Find::name );
              }
        },
        $dir,
    );
    plan tests => 2 + 2 * @classes;

    foreach my $class ( DISTRIBUTION, sort @classes ) {
        use_ok $class or BAIL_OUT("Could not load $class");
        is $class->VERSION, DISTRIBUTION->VERSION,
          "... and $class should have the correct version";
    }
    diag("Testing Test::Harness $Test::Harness::VERSION, Perl $], $^X");
}
