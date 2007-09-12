#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 1;

TODO: {
    local $TODO = 'TAP::Parser screws with STDIN somehow';
    ok -t STDIN, 'STDIN remains a TTY';
}

