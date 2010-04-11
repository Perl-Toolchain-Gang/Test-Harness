#!perl

use strict;
use warnings;

use Test::More tests => 3;

pass("First test");

subtest 'An example subtest' => sub {
    plan tests => 2;

    pass("This is a subtest");
    pass("So is this");
};

pass("Third test");

# vim:ts=2:sw=2:et:ft=perl

