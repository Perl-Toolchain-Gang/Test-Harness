#!perl

use strict;
use warnings;
use Test::More tests => 1;

ok 1, "that's ok";

__DATA__
TAP version 14
ok 1 - We're on 1
# We ran 1
ok 2 - We're on 2
# We ran 2
ok 3 - We're on 3
# We ran 3
  1..3
  ok 1 - We're on 4
  ok 2 - We're on 5
  ok 3 - We're on 6
  PASS
ok 4 - First nest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
#   Failed test at examples/indent.pl line 36.
1..8
# Looks like you failed 1 test of 8.




1..3
ok 1
    1..3
    ok 1
    ok 2
        ok 1
        ok 2
        ok 3
        1..3
    ok 3 - some name
ok 2 - some name
ok 3
