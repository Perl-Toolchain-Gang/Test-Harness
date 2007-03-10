#!/usr/bin/perl -wT

use strict;

use lib 'lib';

use Test::More tests => 202;
use TAP::Parser;
use TAP::Parser::Iterator;

sub _get_results {
    my $parser = shift;
    my @results;
    while ( defined( my $result = $parser->next ) ) {
        push @results => $result;
    }
    return @results;
}

my ( $PARSER, $PLAN, $TEST, $COMMENT, $BAILOUT, $UNKNOWN ) = qw(
  TAP::Parser
  TAP::Parser::Result::Plan
  TAP::Parser::Result::Test
  TAP::Parser::Result::Comment
  TAP::Parser::Result::Bailout
  TAP::Parser::Result::Unknown
);

my $tap = <<'END_TAP';
1..7
ok 1 - input file opened
... this is junk
not ok first line of the input valid # todo some data
# this is a comment
ok 3 - read the rest of the file
not ok 4 - this is a real failure
ok 5 # skip we have no description
ok 6 - you shall not pass! # TODO should have failed
not ok 7 - Gandalf wins.  Game over.  # TODO 'bout time!
END_TAP

can_ok $PARSER, 'new';
ok my $parser = $PARSER->new( { tap => $tap } ),
  '... and calling it should succeed';
isa_ok $parser, $PARSER, '... and the object it returns';

# results() is sane?

ok my @results = _get_results($parser), 'The parser should return results';
is scalar @results, 10, '... and there should be one for each line';

# check the test plan

my $result = shift @results;
isa_ok $result, $PLAN;
can_ok $result, 'type';
is $result->type, 'plan', '... and it should report the correct type';
ok $result->is_plan, '... and it should identify itself as a plan';
is $result->plan, '1..7', '... and identify the plan';
ok !$result->directive,   '... and this plan should not have a directive';
ok !$result->explanation, '... or a directive explanation';
is $result->as_string, '1..7',
  '... and have the correct string representation';
is $result->raw, '1..7', '... and raw() should return the original line';

# a normal, passing test

my $test = shift @results;
isa_ok $test, $TEST;
is $test->type, 'test', '... and it should report the correct type';
ok $test->is_test, '... and it should identify itself as a test';
is $test->ok,      'ok', '... and it should have the correct ok()';
ok $test->is_ok,   '... and the correct boolean version of is_ok()';
ok $test->is_actual_ok,
  '... and the correct boolean version of is_actual_ok()';
is $test->number, 1, '... and have the correct test number';
is $test->description, '- input file opened',
  '... and the correct description';
ok !$test->directive,   '... and not have a directive';
ok !$test->explanation, '... or a directive explanation';
ok !$test->has_skip,    '... and it is not a SKIPped test';
ok !$test->has_todo,    '... nor a TODO test';
is $test->as_string, 'ok 1 - input file opened',
  '... and its string representation should be correct';
is $test->raw, 'ok 1 - input file opened',
  '... and raw() should return the original line';

# junk lines should be preserved

my $unknown = shift @results;
isa_ok $unknown, $UNKNOWN;
is $unknown->type, 'unknown', '... and it should report the correct type';
ok $unknown->is_unknown, '... and it should identify itself as unknown';
is $unknown->as_string,  '... this is junk',
  '... and its string representation should be returned verbatim';
is $unknown->raw, '... this is junk',
  '... and raw() should return the original line';

# a failing test, which also happens to have a directive

my $failed = shift @results;
isa_ok $failed, $TEST;
is $failed->type, 'test', '... and it should report the correct type';
ok $failed->is_test, '... and it should identify itself as a test';
is $failed->ok,      'not ok', '... and it should have the correct ok()';
ok $failed->is_ok,   '... and TODO tests should always pass';
ok !$failed->is_actual_ok,
  '... and the correct boolean version of is_actual_ok ()';
is $failed->number, 2, '... and have the correct failed number';
is $failed->description, 'first line of the input valid',
  '... and the correct description';
is $failed->directive, 'TODO', '... and should have the correct directive';
is $failed->explanation, 'some data',
  '... and the correct directive explanation';
ok !$failed->has_skip, '... and it is not a SKIPped failed';
ok $failed->has_todo, '... but it is a TODO succeeded';
is $failed->as_string,
  'not ok 2 first line of the input valid # TODO some data',
  '... and its string representation should be correct';
is $failed->raw, 'not ok first line of the input valid # todo some data',
  '... and raw() should return the original line';

# comments

my $comment = shift @results;
isa_ok $comment, $COMMENT;
is $comment->type, 'comment', '... and it should report the correct type';
ok $comment->is_comment, '... and it should identify itself as a comment';
is $comment->comment,    'this is a comment',
  '... and you should be able to fetch the comment';
is $comment->as_string, '# this is a comment',
  '... and have the correct string representation';
is $comment->raw, '# this is a comment',
  '... and raw() should return the original line';

# another normal, passing test

$test = shift @results;
isa_ok $test, $TEST;
is $test->type, 'test', '... and it should report the correct type';
ok $test->is_test, '... and it should identify itself as a test';
is $test->ok,      'ok', '... and it should have the correct ok()';
ok $test->is_ok,   '... and the correct boolean version of is_ok()';
ok $test->is_actual_ok,
  '... and the correct boolean version of is_actual_ok()';
is $test->number, 3, '... and have the correct test number';
is $test->description, '- read the rest of the file',
  '... and the correct description';
ok !$test->directive,   '... and not have a directive';
ok !$test->explanation, '... or a directive explanation';
ok !$test->has_skip,    '... and it is not a SKIPped test';
ok !$test->has_todo,    '... nor a TODO test';
is $test->as_string, 'ok 3 - read the rest of the file',
  '... and its string representation should be correct';
is $test->raw, 'ok 3 - read the rest of the file',
  '... and raw() should return the original line';

# a failing test

$failed = shift @results;
isa_ok $failed, $TEST;
is $failed->type, 'test', '... and it should report the correct type';
ok $failed->is_test, '... and it should identify itself as a test';
is $failed->ok, 'not ok', '... and it should have the correct ok()';
ok !$failed->is_ok, '... and the tests should not have passed';
ok !$failed->is_actual_ok,
  '... and the correct boolean version of is_actual_ok ()';
is $failed->number, 4, '... and have the correct failed number';
is $failed->description, '- this is a real failure',
  '... and the correct description';
ok !$failed->directive,   '... and should have no directive';
ok !$failed->explanation, '... and no directive explanation';
ok !$failed->has_skip,    '... and it is not a SKIPped failed';
ok !$failed->has_todo,    '... and not a TODO test';
is $failed->as_string, 'not ok 4 - this is a real failure',
  '... and its string representation should be correct';
is $failed->raw, 'not ok 4 - this is a real failure',
  '... and raw() should return the original line';

# ok 5 # skip we have no description
# skipped test

$test = shift @results;
isa_ok $test, $TEST;
is $test->type, 'test', '... and it should report the correct type';
ok $test->is_test, '... and it should identify itself as a test';
is $test->ok,      'ok', '... and it should have the correct ok()';
ok $test->is_ok,   '... and the correct boolean version of is_ok()';
ok $test->is_actual_ok,
  '... and the correct boolean version of is_actual_ok()';
is $test->number, 5, '... and have the correct test number';
ok !$test->description, '... and skipped tests have no description';
is $test->directive, 'SKIP', '... and teh correct directive';
is $test->explanation, 'we have no description',
  '... but we should have an explanation';
ok $test->has_skip, '... and it is a SKIPped test';
ok !$test->has_todo, '... but not a TODO test';
is $test->as_string, 'ok 5 # SKIP we have no description',
  '... and its string representation should be correct';
is $test->raw, 'ok 5 # skip we have no description',
  '... and raw() should return the original line';

# a failing test, which also happens to have a directive
# ok 6 - you shall not pass! # TODO should have failed

my $bonus = shift @results;
isa_ok $bonus, $TEST;
can_ok $bonus, 'todo_passed';
is $bonus->type, 'test', 'TODO tests should parse correctly';
ok $bonus->is_test, '... and it should identify itself as a test';
is $bonus->ok,      'ok', '... and it should have the correct ok()';
ok $bonus->is_ok,   '... and TODO tests should not always pass';
ok $bonus->is_actual_ok,
  '... and the correct boolean version of is_actual_ok ()';
is $bonus->number, 6, '... and have the correct failed number';
is $bonus->description, '- you shall not pass!',
  '... and the correct description';
is $bonus->directive, 'TODO', '... and should have the correct directive';
is $bonus->explanation, 'should have failed',
  '... and the correct directive explanation';
ok !$bonus->has_skip, '... and it is not a SKIPped failed';
ok $bonus->has_todo,  '... but it is a TODO succeeded';
is $bonus->as_string, 'ok 6 - you shall not pass! # TODO should have failed',
  '... and its string representation should be correct';
is $bonus->raw, 'ok 6 - you shall not pass! # TODO should have failed',
  '... and raw() should return the original line';
ok $bonus->todo_passed,
  '... todo_bonus() should pass for TODO tests which unexpectedly succeed';

# not ok 7 - Gandalf wins.  Game over.  # TODO 'bout time!

my $passed = shift @results;
isa_ok $passed, $TEST;
can_ok $passed, 'todo_passed';
is $passed->type, 'test', 'TODO tests should parse correctly';
ok $passed->is_test, '... and it should identify itself as a test';
is $passed->ok,      'not ok', '... and it should have the correct ok()';
ok $passed->is_ok,   '... and TODO tests should always pass';
ok !$passed->is_actual_ok,
  '... and the correct boolean version of is_actual_ok ()';
is $passed->number, 7, '... and have the correct passed number';
is $passed->description, '- Gandalf wins.  Game over.',
  '... and the correct description';
is $passed->directive, 'TODO', '... and should have the correct directive';
is $passed->explanation, "'bout time!",
  '... and the correct directive explanation';
ok !$passed->has_skip, '... and it is not a SKIPped passed';
ok $passed->has_todo, '... but it is a TODO succeeded';
is $passed->as_string,
  "not ok 7 - Gandalf wins.  Game over. # TODO 'bout time!",
  '... and its string representation should be correct';
is $passed->raw, "not ok 7 - Gandalf wins.  Game over.  # TODO 'bout time!",
  '... and raw() should return the original line';
ok !$passed->todo_passed,
  '... todo_passed() should not pass for TODO tests which failed';

# test parse results

can_ok $parser, 'passed';
is $parser->passed, 6,
  '... and we should have the correct number of passed tests';
is_deeply [ $parser->passed ], [ 1, 2, 3, 5, 6, 7 ],
  '... and get a list of the passed tests';

can_ok $parser, 'failed';
is $parser->failed, 1, '... and the correct number of failed tests';
is_deeply [ $parser->failed ], [4], '... and get a list of the failed tests';

can_ok $parser, 'actual_passed';
is $parser->actual_passed, 4,
  '... and we should have the correct number of actually passed tests';
is_deeply [ $parser->actual_passed ], [ 1, 3, 5, 6 ],
  '... and get a list of the actually passed tests';

can_ok $parser, 'actual_failed';
is $parser->actual_failed, 3,
  '... and the correct number of actually failed tests';
is_deeply [ $parser->actual_failed ], [ 2, 4, 7 ],
  '... or get a list of the actually failed tests';

can_ok $parser, 'todo';
is $parser->todo, 3,
  '... and we should have the correct number of TODO tests';
is_deeply [ $parser->todo ], [ 2, 6, 7 ],
  '... and get a list of the TODO tests';

can_ok $parser, 'skipped';
is $parser->skipped, 1,
  '... and we should have the correct number of skipped tests';
is_deeply [ $parser->skipped ], [5],
  '... and get a list of the skipped tests';

# check the plan

can_ok $parser, 'plan';
is $parser->plan,          '1..7', '... and we should have the correct plan';
is $parser->tests_planned, 7,      '... and the correct number of tests';

# "Unexpectedly succeeded"
can_ok $parser, 'todo_passed';
is scalar $parser->todo_passed, 1,
  '... and it should report the number of tests which unexpectedly succeeded';
is_deeply [ $parser->todo_passed ], [6],
  '... or *which* tests unexpectedly succeeded';

#
# Bug report from Torsten Schoenfeld
# Makes sure parser can handle blank lines
#

$tap = <<'END_TAP';
1..2
ok 1 - input file opened


ok 2 - read the rest of the file
END_TAP

my $aref = [ split /\n/ => $tap ];

can_ok $PARSER, 'new';
ok $parser = $PARSER->new( { stream => TAP::Parser::Iterator->new($aref) } ),
  '... and calling it should succeed';
isa_ok $parser, $PARSER, '... and the object it returns';

# results() is sane?

ok @results = _get_results($parser), 'The parser should return results';
is scalar @results, 5, '... and there should be one for each line';

# check the test plan

$result = shift @results;
isa_ok $result, $PLAN;
can_ok $result, 'type';
is $result->type, 'plan', '... and it should report the correct type';
ok $result->is_plan,   '... and it should identify itself as a plan';
is $result->plan,      '1..2', '... and identify the plan';
is $result->as_string, '1..2',
  '... and have the correct string representation';
is $result->raw, '1..2', '... and raw() should return the original line';

# a normal, passing test

$test = shift @results;
isa_ok $test, $TEST;
is $test->type, 'test', '... and it should report the correct type';
ok $test->is_test, '... and it should identify itself as a test';
is $test->ok,      'ok', '... and it should have the correct ok()';
ok $test->is_ok,   '... and the correct boolean version of is_ok()';
ok $test->is_actual_ok,
  '... and the correct boolean version of is_actual_ok()';
is $test->number, 1, '... and have the correct test number';
is $test->description, '- input file opened',
  '... and the correct description';
ok !$test->directive,   '... and not have a directive';
ok !$test->explanation, '... or a directive explanation';
ok !$test->has_skip,    '... and it is not a SKIPped test';
ok !$test->has_todo,    '... nor a TODO test';
is $test->as_string, 'ok 1 - input file opened',
  '... and its string representation should be correct';
is $test->raw, 'ok 1 - input file opened',
  '... and raw() should return the original line';

# junk lines should be preserved

$unknown = shift @results;
isa_ok $unknown, $UNKNOWN;
is $unknown->type, 'unknown', '... and it should report the correct type';
ok $unknown->is_unknown, '... and it should identify itself as unknown';
is $unknown->as_string,  '',
  '... and its string representation should be returned verbatim';
is $unknown->raw, '', '... and raw() should return the original line';

# ... and the second empty line

$unknown = shift @results;
isa_ok $unknown, $UNKNOWN;
is $unknown->type, 'unknown', '... and it should report the correct type';
ok $unknown->is_unknown, '... and it should identify itself as unknown';
is $unknown->as_string,  '',
  '... and its string representation should be returned verbatim';
is $unknown->raw, '', '... and raw() should return the original line';

# a passing test

$test = shift @results;
isa_ok $test, $TEST;
is $test->type, 'test', '... and it should report the correct type';
ok $test->is_test, '... and it should identify itself as a test';
is $test->ok,      'ok', '... and it should have the correct ok()';
ok $test->is_ok,   '... and the correct boolean version of is_ok()';
ok $test->is_actual_ok,
  '... and the correct boolean version of is_actual_ok()';
is $test->number, 2, '... and have the correct test number';
is $test->description, '- read the rest of the file',
  '... and the correct description';
ok !$test->directive,   '... and not have a directive';
ok !$test->explanation, '... or a directive explanation';
ok !$test->has_skip,    '... and it is not a SKIPped test';
ok !$test->has_todo,    '... nor a TODO test';
is $test->as_string, 'ok 2 - read the rest of the file',
  '... and its string representation should be correct';
is $test->raw, 'ok 2 - read the rest of the file',
  '... and raw() should return the original line';

is scalar $parser->passed, 2,
  'Empty junk lines should not affect the correct number of tests passed';
