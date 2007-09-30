#!/usr/bin/perl -w

# Test that @INC is propogated from the harness process to the test
# process.


use strict;
use lib 't/lib';

use Test::More tests => 2;

# Ensure we include code-time changes to @INC
use lib "wibble";

use Data::Dumper;
use TAP::Harness;

my $inc = Data::Dumper->new([\@INC])->Terse(1)->Purity(1)->Dump;
my $taint_inc = 
  Data::Dumper->new([[grep { $_ ne '.' } @INC]])->Terse(1)->Purity(1)->Dump;

my $test_template = <<'END';
#!/usr/bin/perl %s

use Test::More tests => 1;

sub _strip_dups {
    my %%dups;
    return grep { !$dups{$_}++ } @_;
}

is_deeply(
    [_strip_dups(@INC)],
    [_strip_dups(@{%s})],
    '@INC propegated to test'
) or do {
    diag join ",\n", @INC;
    diag "%s";
};
END

open TEST, ">inc_check.t.tmp";
printf TEST $test_template, '', $inc, $inc;
close TEST;

open TEST, ">inc_check_taint.t.tmp";
printf TEST $test_template, '-T', $taint_inc, $taint_inc;
close TEST;
END { 1 while unlink 'inc_check_taint.t.tmp', 'inc_check.t.tmp'; }

for my $test ( 'inc_check_taint.t.tmp', 'inc_check.t.tmp' ) {
    my $parser = TAP::Parser->new({ source => $test });
    1 while $parser->next;
    ok !$parser->failed, $test;
}
1;
