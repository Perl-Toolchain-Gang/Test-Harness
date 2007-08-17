#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

sub _all_ok {
    my ($tot) = shift;
    return $tot->{bad} == 0 && ( $tot->{max} || $tot->{skipped} ) ? 1 : 0;
}

use TAP::Harness::Compatible;
use Test::More tests => 1;
use Dev::Null;

{
    local $ENV{PERL_TEST_HARNESS_DUMP_TAP} = 0;

    push @INC, 'we_added_this_lib';

    tie *NULL, 'Dev::Null' or die $!;
    select NULL;
    my ( $tot, $failed ) = TAP::Harness::Compatible::execute_tests(
        tests => [
            $ENV{PERL_CORE}
            ? 'lib/sample-tests/inc_taint'
            : 't/sample-tests/inc_taint'
        ]
    );
    select STDOUT;

    ok( _all_ok($tot), 'tests with taint on preserve @INC' );
}
