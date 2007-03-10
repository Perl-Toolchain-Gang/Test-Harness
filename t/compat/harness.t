#!/usr/bin/perl -Tw

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::More;

#plan tests => 2;
plan skip_all => 'Harness has no Straps support yet';

BEGIN {
    use_ok('TAP::Harness::Compatible');
}

my $strap = TAP::Harness::Compatible->strap;
isa_ok( $strap, 'TAP::Harness::Compatible::Straps' );
