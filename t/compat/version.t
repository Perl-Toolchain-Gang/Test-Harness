#!/usr/bin/perl -Tw

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::More tests => 3;

BEGIN {
    use_ok('TAPx::Harness::Compatible');
}

my $ver = $ENV{HARNESS_VERSION} or die "HARNESS_VERSION not set";
TODO: {
    local $TODO = "Our version isn't numeric";
    ok( $ver =~ /^2.\d\d(_\d\d)?$/, "Version is proper format" );
}
is( $ver, $TAPx::Harness::Compatible::VERSION );
