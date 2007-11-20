#!/usr/bin/perl -w

# Test that @INC is propogated from the harness process to the test
# process.

use strict;
use lib 't/lib';

use Test::More tests => 1;
use Test::Harness;

my $test_template = <<'END';
#!/usr/bin/perl

use Test::More tests => 1;

is $ENV{HARNESS_PERL_SWITCHES}, '-w';
END

open TEST, ">env_check.t.tmp";
print TEST $test_template;
close TEST;

END { unlink 'env_check.t.tmp'; }

{
    local $ENV{HARNESS_PERL_SWITCHES} = '-w';
    my ( $tot, $failed )
      = Test::Harness::execute_tests( tests => ['env_check.t.tmp'] );
    is $tot->{bad}, 0;
}

1;
