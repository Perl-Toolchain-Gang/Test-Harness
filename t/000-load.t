#!/usr/bin/perl -wT

use strict;

use File::Spec;
use File::Find;
use Test::More tests => 56;

sub file_to_pm {
    my ( $dir, $file ) = @_;
    $file =~ s/\.pm$// || return;    # we only care about .pm files
    $file =~ s{\\}{/}g;              # to make win32 happy
    $dir  =~ s{\\}{/}g;              # to make win32 happy
    $file =~ s/^$dir//;
    my $_package = join '::' => grep $_ => File::Spec->splitdir($file);

    # untaint that puppy!
    my ($package) = $_package =~ /^([\w]+(?:::[\w]+)*)$/;
    return 'TAP::Parser' eq $package ? () : $package;
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

    # TAP::Parser must come first
    foreach my $class ( 'TAP::Parser', sort @classes ) {
        use_ok $class;
        is $class->VERSION, TAP::Parser->VERSION,
          "... and $class should have the correct version";
    }
    diag("Testing Test::Harness $Test::Harness::VERSION, Perl $], $^X");
}
