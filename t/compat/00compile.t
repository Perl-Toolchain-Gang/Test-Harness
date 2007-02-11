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

use Test::More tests => 6;

BEGIN { use_ok 'TAPx::Harness::Compatible' }

BEGIN {
    diag(
        "Testing TAPx::Harness::Compatible $TAPx::Harness::Compatible::VERSION under Perl $] and Test::More $Test::More::VERSION"
    ) unless $ENV{PERL_CORE};
}

BEGIN { use_ok 'TAPx::Harness::Compatible::Straps' }

BEGIN { use_ok 'TAPx::Harness::Compatible::Iterator' }

BEGIN { use_ok 'TAPx::Harness::Compatible::Point' }

BEGIN { use_ok 'TAPx::Harness::Compatible::Results' }

BEGIN { use_ok 'TAPx::Harness::Compatible::Util' }

# If the $VERSION is set improperly, this will spew big warnings.
#BEGIN { use_ok 'TAPx::Harness::Compatible', 1.1601 }

