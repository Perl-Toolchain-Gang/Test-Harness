#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 1;

BEGIN { use_ok 'Test::Harness' }

BEGIN {
    diag(
        "Testing Test::Harness $Test::Harness::VERSION under Perl $] and Test::More $Test::More::VERSION"
    ) unless $ENV{PERL_CORE};
}
