#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
    else {
        unshift @INC, 't/lib';
    }
}

use Test::More tests => 1;

BEGIN { use_ok 'TAP::Harness::Compatible' }

BEGIN {
    diag(
        "Testing TAP::Harness::Compatible $TAP::Harness::Compatible::VERSION under Perl $] and Test::More $Test::More::VERSION"
    ) unless $ENV{PERL_CORE};
}
