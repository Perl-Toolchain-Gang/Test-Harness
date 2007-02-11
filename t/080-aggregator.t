#!/usr/bin/perl -wT

use strict;

use lib 'lib';
use TAPx::Parser;
use TAPx::Parser::Iterator;
use TAPx::Parser::Aggregator;

use Test::More tests => 34;

my $tap = <<'END_TAP';
1..5
ok 1 - input file opened
... this is junk
not ok first line of the input valid # todo some data
# this is a comment
ok 3 - read the rest of the file
not ok 4 - this is a real failure
ok 5 # skip we have no description
END_TAP

my $stream = TAPx::Parser::Iterator->new( [ split /\n/ => $tap ] );
my $parser1 = TAPx::Parser->new( { stream => $stream } );
$parser1->run;

$tap = <<'END_TAP';
1..7
ok 1 - gentleman, start your engines
not ok first line of the input valid # todo some data
# this is a comment
ok 3 - read the rest of the file
not ok 4 - this is a real failure
ok 5 
ok 6 - you shall not pass! # TODO should have failed
not ok 7 - Gandalf wins.  Game over.  # TODO 'bout time!
END_TAP

my $parser2 = TAPx::Parser->new( { tap => $tap } );
$parser2->run;

can_ok 'TAPx::Parser::Aggregator', 'new';
ok my $agg = TAPx::Parser::Aggregator->new,
  '... and calling it should succeed';
isa_ok $agg, 'TAPx::Parser::Aggregator', '... and the object it returns';

can_ok $agg, 'add';
ok $agg->add( 'tap1', $parser1 ), '... and calling it should succeed';
ok $agg->add( 'tap2', $parser2 ), '... even if we add more than one parser';
eval { $agg->add( 'tap1', $parser1 ) };
like $@, qr/^You already have a parser for \Q(tap1)/,
  '... but trying to reuse a description should be fatal';

can_ok $agg, 'parsers';
is scalar $agg->parsers, 2,
  '... and it should report how many parsers it has';
is_deeply [ $agg->parsers ], [ $parser1, $parser2 ],
  '... or which parsers it has';
is_deeply $agg->parsers('tap2'), $parser2, '... or reporting a single parser';
is_deeply [ $agg->parsers(qw(tap2 tap1)) ], [ $parser2, $parser1 ],
  '... or a group';

# test aggregate results

can_ok $agg, 'passed';
is $agg->passed, 10,
  '... and we should have the correct number of passed tests';
is_deeply [ $agg->passed ], [qw(tap1 tap2)],
  '... and be able to get their descriptions';

can_ok $agg, 'failed';
is $agg->failed, 2,
  '... and we should have the correct number of failed tests';
is_deeply [ $agg->failed ], [qw(tap1 tap2)],
  '... and be able to get their descriptions';

can_ok $agg, 'todo';
is $agg->todo, 4, '... and we should have the correct number of todo tests';
is_deeply [ $agg->todo ], [qw(tap1 tap2)],
  '... and be able to get their descriptions';

can_ok $agg, 'skipped';
is $agg->skipped, 1,
  '... and we should have the correct number of skipped tests';
is_deeply [ $agg->skipped ], [qw(tap1)],
  '... and be able to get their descriptions';

can_ok $agg, 'parse_errors';
is $agg->parse_errors, 0, '... and the correct number of parse errors';
is_deeply [ $agg->parse_errors ], [],
  '... and be able to get their descriptions';

can_ok $agg, 'todo_passed';
is $agg->todo_passed, 1,
  '... and the correct number of unexpectedly succeeded tests';
is_deeply [ $agg->todo_passed ], [qw(tap2)],
  '... and be able to get their descriptions';

can_ok $agg, 'total';
is $agg->total, $agg->passed + $agg->failed,
  '... and we should have the correct number of total tests';

can_ok $agg, 'has_problems';
ok $agg->has_problems, '... and it should report true if there are problems';
