#!/usr/bin/perl -w

use strict;

use lib 'lib';
use TAP::Parser::Grammar;
use TAP::Parser::Iterator::Array;

use Test::More tests => 69;

my $GRAMMAR = 'TAP::Parser::Grammar';

# Array based stream that we can push items in to
package SS;

sub new {
    my $class = shift;
    return bless [], $class;
}

sub next {
    my $self = shift;
    return shift @$self;
}

sub put {
    my $self = shift;
    unshift @$self, @_;
}

package main;

my $stream = SS->new;
can_ok $GRAMMAR, 'new';
ok my $grammar = $GRAMMAR->new( $stream ), '... and calling it should succeed';
isa_ok $grammar, $GRAMMAR, '... and the object it returns';

# Note:  all methods are actually class methods.  See the docs for the reason
# why.  We'll still use the instance because that should be forward
# compatible.

my @V12 = qw(bailout comment plan test version);
my @V13 = ( @V12, 'yaml' );

can_ok $grammar, 'token_types';
ok my @types = sort( $grammar->token_types ),
  '... and calling it should succeed (v12)';
is_deeply \@types, \@V12, '... and return the correct token types (v12)';

$grammar->set_version( 13 );
ok @types = sort( $grammar->token_types ),
  '... and calling it should succeed (v13)';
is_deeply \@types, \@V13, '... and return the correct token types (v13)';

can_ok $grammar, 'syntax_for';
can_ok $grammar, 'handler_for';

my ( %syntax_for, %handler_for );
foreach my $type ( @types ) {
    ok $syntax_for{$type} = $grammar->syntax_for( $type ),
      '... and calling syntax_for() with a type name should succeed';
    cmp_ok ref $syntax_for{$type}, 'eq', 'Regexp',
      '... and it should return a regex';

    ok $handler_for{$type} = $grammar->handler_for( $type ),
      '... and calling handler_for() with a type name should succeed';
    cmp_ok ref $handler_for{$type}, 'eq', 'CODE',
      '... and it should return a code reference';
}

# Test the plan.  Gotta have a plan.
my $plan = '1..1';
like $plan, $syntax_for{'plan'}, 'A basic plan should match its syntax';

my $method = $handler_for{'plan'};
$plan =~ $syntax_for{'plan'};
ok my $plan_token = $grammar->$method( $plan ),
  '... and the handler should return a token';

my $expected = {
    'explanation'   => '',
    'directive'     => '',
    'type'          => 'plan',
    'tests_planned' => 1,
    'raw'           => '1..1'
};
is_deeply $plan_token, $expected, '... and it should contain the correct data';

can_ok $grammar, 'tokenize';
$stream->put( $plan );
ok my $token = $grammar->tokenize,
  '... and calling it with data should return a token';
is_deeply $token, $expected,
  '... and the token should contain the correct data';

# a plan with a skip directive

$plan = '1..0 # SKIP why not?';
like $plan, $syntax_for{'plan'}, 'a basic plan should match its syntax';

$plan =~ $syntax_for{'plan'};
ok $plan_token = $grammar->$method( $plan ),
  '... and the handler should return a token';

$expected = {
    'explanation'   => 'why not?',
    'directive'     => 'SKIP',
    'type'          => 'plan',
    'tests_planned' => 0,
    'raw'           => '1..0 # SKIP why not?'
};
is_deeply $plan_token, $expected, '... and it should contain the correct data';

$stream->put( $plan );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';
is_deeply $token, $expected,
  '... and the token should contain the correct data';

# implied skip

$plan = '1..0';
like $plan, $syntax_for{'plan'},
  'A plan  with an implied "skip all" should match its syntax';

$plan =~ $syntax_for{'plan'};
ok $plan_token = $grammar->$method( $plan ),
  '... and the handler should return a token';

$expected = {
    'explanation'   => '',
    'directive'     => 'SKIP',
    'type'          => 'plan',
    'tests_planned' => 0,
    'raw'           => '1..0'
};
is_deeply $plan_token, $expected, '... and it should contain the correct data';

$stream->put( $plan );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';
is_deeply $token, $expected,
  '... and the token should contain the correct data';

# bad plan

$plan = '1..0 # TODO 3,4,5';    # old syntax.  No longer supported
unlike $plan, $syntax_for{'plan'}, 'Bad plans should not match the plan syntax';

# Bail out!

my $bailout = 'Bail out!';
like $bailout, $syntax_for{'bailout'},
  'Bail out! should match a bailout syntax';

$stream->put( $bailout );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';
$expected = {
    'bailout' => '',
    'type'    => 'bailout',
    'raw'     => 'Bail out!'
};
is_deeply $token, $expected,
  '... and the token should contain the correct data';

$bailout = 'Bail out! some explanation';
like $bailout, $syntax_for{'bailout'},
  'Bail out! should match a bailout syntax';

$stream->put( $bailout );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';
$expected = {
    'bailout' => 'some explanation',
    'type'    => 'bailout',
    'raw'     => 'Bail out! some explanation'
};
is_deeply $token, $expected,
  '... and the token should contain the correct data';

# test comment

my $comment = '# this is a comment';
like $comment, $syntax_for{'comment'},
  'Comments should match the comment syntax';

$stream->put( $comment );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';
$expected = {
    'comment' => 'this is a comment',
    'type'    => 'comment',
    'raw'     => '# this is a comment'
};
is_deeply $token, $expected,
  '... and the token should contain the correct data';

# test tests :/

my $test = 'ok 1 this is a test';
like $test, $syntax_for{'test'}, 'Tests should match the test syntax';

$stream->put( $test );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';

$expected = {
    'ok'          => 'ok',
    'explanation' => '',
    'type'        => 'test',
    'directive'   => '',
    'description' => 'this is a test',
    'test_num'    => '1',
    'raw'         => 'ok 1 this is a test'
};
is_deeply $token, $expected,
  '... and the token should contain the correct data';

# TODO tests

$test = 'not ok 2 this is a test # TODO whee!';
like $test, $syntax_for{'test'}, 'Tests should match the test syntax';

$stream->put( $test );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';

$expected = {
    'ok'          => 'not ok',
    'explanation' => 'whee!',
    'type'        => 'test',
    'directive'   => 'TODO',
    'description' => 'this is a test',
    'test_num'    => '2',
    'raw'         => 'not ok 2 this is a test # TODO whee!'
};
is_deeply $token, $expected, '... and the TODO should be parsed';

# false TODO tests

# escaping that hash mark ('#') means this should *not* be a TODO test
$test = 'ok 22 this is a test \# TODO whee!';
like $test, $syntax_for{'test'}, 'Tests should match the test syntax';

$stream->put( $test );
ok $token = $grammar->tokenize,
  '... and calling it with data should return a token';

$expected = {
    'ok'          => 'ok',
    'explanation' => '',
    'type'        => 'test',
    'directive'   => '',
    'description' => 'this is a test \# TODO whee!',
    'test_num'    => '22',
    'raw'         => 'ok 22 this is a test \# TODO whee!'
};
is_deeply $token, $expected,
  '... and the token should contain the correct data';
