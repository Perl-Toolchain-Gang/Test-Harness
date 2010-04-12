#!perl

use strict;
use warnings;

use Data::Dumper;
use TAP::Parser;
use Test::More;

my @tests = (
    {   name => 'Simple nesting',
        tap  => <<'EOT',
TAP version 14
ok 1 - We're on 1
ok 2 - We're on 2
ok 3 - We're on 3
    1..3
    ok 1 - We're on 4
    ok 2 - We're on 5
    ok 3 - We're on 6
ok 4 - First nest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
1..8
EOT
        expect => [
            { nesting => 0, type => 'version', version       => 14, },
            { nesting => 0, type => 'test',    number        => 1, },
            { nesting => 0, type => 'test',    number        => 2, },
            { nesting => 0, type => 'test',    number        => 3, },
            { nesting => 0, type => 'nest_in' },
            { nesting => 1, type => 'plan',    tests_planned => 3, },
            { nesting => 1, type => 'test',    number        => 1, },
            { nesting => 1, type => 'test',    number        => 2, },
            { nesting => 1, type => 'test',    number        => 3, },
            { nesting => 1, type => 'nest_out' },
            { nesting => 0, type => 'test',    number        => 4, },
            { nesting => 0, type => 'test',    number        => 5, },
            { nesting => 0, type => 'test',    number        => 6, },
            { nesting => 0, type => 'test',    number        => 7, },
            { nesting => 0, type => 'test',    number        => 8, },
            { nesting => 0, type => 'plan',    tests_planned => 8, }
        ]
    },
    {   name => 'Yamlish',
        tap  => <<'EOT',
TAP version 14
ok 1 - We're on 1
ok 2 - We're on 2
ok 3 - We're on 3
    1..3
    ok 1 - We're on 4
      ---
      -
        sneep: skib
        ponk: brek
      ...
    ok 2 - We're on 5
    ok 3 - We're on 6
ok 4 - First nest
  ---
  -
    fnurk: skib
    ponk: gleeb
  -
    bar: krup
    foo: plink
  ...
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
1..8
EOT
        expect => [
            { nesting => 0, type => 'version', version       => 14, },
            { nesting => 0, type => 'test',    number        => 1, },
            { nesting => 0, type => 'test',    number        => 2, },
            { nesting => 0, type => 'test',    number        => 3, },
            { nesting => 0, type => 'nest_in' },
            { nesting => 1, type => 'plan',    tests_planned => 3, },
            { nesting => 1, type => 'test',    number        => 1, },
            { nesting => 1, type => 'yaml', },
            { nesting => 1, type => 'test',    number        => 2, },
            { nesting => 1, type => 'test',    number        => 3, },
            { nesting => 1, type => 'nest_out' },
            { nesting => 0, type => 'test',    number        => 4, },
            { nesting => 0, type => 'yaml', },
            { nesting => 0, type => 'test',    number        => 5, },
            { nesting => 0, type => 'test',    number        => 6, },
            { nesting => 0, type => 'test',    number        => 7, },
            { nesting => 0, type => 'test',    number        => 8, },
            { nesting => 0, type => 'plan',    tests_planned => 8, }
        ]
    },
    {   name => 'Trailing plan in nest',
        tap  => <<'EOT',
TAP version 14
ok 1 - We're on 1
ok 2 - We're on 2
ok 3 - We're on 3
    ok 1 - We're on 4
    ok 2 - We're on 5
    ok 3 - We're on 6
    1..3
ok 4 - First nest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
1..8
EOT
        expect => [
            { nesting => 0, type => 'version', version       => 14, },
            { nesting => 0, type => 'test',    number        => 1, },
            { nesting => 0, type => 'test',    number        => 2, },
            { nesting => 0, type => 'test',    number        => 3, },
            { nesting => 0, type => 'nest_in' },
            { nesting => 1, type => 'test',    number        => 1, },
            { nesting => 1, type => 'test',    number        => 2, },
            { nesting => 1, type => 'test',    number        => 3, },
            { nesting => 1, type => 'plan',    tests_planned => 3, },
            { nesting => 1, type => 'nest_out' },
            { nesting => 0, type => 'test',    number        => 4, },
            { nesting => 0, type => 'test',    number        => 5, },
            { nesting => 0, type => 'test',    number        => 6, },
            { nesting => 0, type => 'test',    number        => 7, },
            { nesting => 0, type => 'test',    number        => 8, },
            { nesting => 0, type => 'plan',    tests_planned => 8, }
        ]
    },
    {   name => 'No version',
        tap  => <<'EOT',
ok 1 - We're on 1
ok 2 - We're on 2
ok 3 - We're on 3
    1..3
    ok 1 - We're on 4
    ok 2 - We're on 5
    ok 3 - We're on 6
ok 4 - First nest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
1..8
EOT
        expect => [
            { nesting => 0, type => 'test', number        => 1, },
            { nesting => 0, type => 'test', number        => 2, },
            { nesting => 0, type => 'test', number        => 3, },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'test', number        => 4, },
            { nesting => 0, type => 'test', number        => 5, },
            { nesting => 0, type => 'test', number        => 6, },
            { nesting => 0, type => 'test', number        => 7, },
            { nesting => 0, type => 'test', number        => 8, },
            { nesting => 0, type => 'plan', tests_planned => 8, }
        ]
    },
    {   name => 'Crazy nesting',
        tap  => <<'EOT',
TAP version 14
ok 1 - We're on 1
ok 2 - We're on 2
ok 3 - We're on 3
    1..3
    ok 1 - We're on 4
    ok 2 - We're on 5
  ok 3 - We're on 6
ok 4 - First nest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
1..8
EOT
        expect => [
            { nesting => 0, type => 'version', version       => 14, },
            { nesting => 0, type => 'test',    number        => 1, },
            { nesting => 0, type => 'test',    number        => 2, },
            { nesting => 0, type => 'test',    number        => 3, },
            { nesting => 0, type => 'nest_in' },
            { nesting => 1, type => 'plan',    tests_planned => 3, },
            { nesting => 1, type => 'test',    number        => 1, },
            { nesting => 1, type => 'test',    number        => 2, },
            { nesting => 1, type => 'nest_out' },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'test',    number        => 4, },
            { nesting => 0, type => 'test',    number        => 5, },
            { nesting => 0, type => 'test',    number        => 6, },
            { nesting => 0, type => 'test',    number        => 7, },
            { nesting => 0, type => 'test',    number        => 8, },
            { nesting => 0, type => 'plan',    tests_planned => 8, }
        ]
    },
    {   name => 'Not four spaces',
        tap  => <<'EOT',
TAP version 14
ok 1 - We're on 1
ok 2 - We're on 2
ok 3 - We're on 3
  1..3
  ok 1 - We're on 4
  ok 2 - We're on 5
  ok 3 - We're on 6
ok 4 - First nest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
not ok 8
1..8
EOT
        expect => [
            { nesting => 0, type => 'version', version       => 14, },
            { nesting => 0, type => 'test',    number        => 1, },
            { nesting => 0, type => 'test',    number        => 2, },
            { nesting => 0, type => 'test',    number        => 3, },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'unknown', },
            { nesting => 0, type => 'test',    number        => 4, },
            { nesting => 0, type => 'test',    number        => 5, },
            { nesting => 0, type => 'test',    number        => 6, },
            { nesting => 0, type => 'test',    number        => 7, },
            { nesting => 0, type => 'test',    number        => 8, },
            { nesting => 0, type => 'plan',    tests_planned => 8, }
        ]
    },
);

plan tests => @tests * 2;

for my $test (@tests) {
    my ( $name, $tap, $expect ) = @{$test}{ 'name', 'tap', 'expect' };
    my $results = eval { slurp_tap($tap) };
    ok !$@, "$name: parsed without error" or diag $@;
    is_result( $results, $expect, "$name: results match" );
}

sub is_result {
    my ( $results, $expect, $msg ) = @_;
    my @keep = qw(
      version nesting type tests_planned number
    );
    my @got = ();
    for my $r (@$results) {
        my $rec = {};
        for my $k (@keep) {
            $rec->{$k} = $r->$k() if $r->can($k);
        }
        push @got, $rec;
    }
    unless ( is_deeply \@got, $expect, $msg ) {
        diag Dumper($results);
    }
}

sub slurp_tap {
    my $tap     = shift;
    my $parser  = TAP::Parser->new( { tap => $tap } );
    my @results = ();
    while ( my $result = $parser->next ) {
        push @results, $result;
    }
    return \@results;
}
