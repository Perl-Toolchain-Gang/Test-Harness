#!/usr/bin/perl -w

use strict;
use warnings;

use TAP::Harness::Runtime qw (IS_VMS);
use Test::More (
    IS_VMS
    ? ( skip_all => 'VMS' )
    : ( tests => 4 )
);

use Test::Harness;

for my $switch ( '-Ifoo', '-I foo' ) {
    $Test::Harness::Switches = $switch;
    ok my $harness = Test::Harness::_new_harness, 'made harness';
    is +($harness->lib)[0], '-Ifoo', 'got libs';
}

