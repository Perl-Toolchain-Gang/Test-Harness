#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 1;

use File::Spec;
use TAP::Parser;

my $parser = TAP::Parser->new(
    { source => File::Spec->catfile( 't', 'sample-tests', 'blocks' ) } );

my @results = ();

while ( my $result = $parser->next ) {
    push @results, $result;
}

my @expect = (
    bless(
        {   'version' => '14',
            'type'    => 'version',
            'raw'     => 'TAP version 14'
        },
        'TAP::Parser::Result::Version'
    ),
    bless(
        {   'explanation'   => '',
            'todo_list'     => [],
            'directive'     => '',
            'type'          => 'plan',
            'tests_planned' => 4,
            'raw'           => '1..4'
        },
        'TAP::Parser::Result::Plan'
    ),
    bless(
        {   'type'        => 'begin',
            'description' => 'First block',
            'test_num'    => '1',
            'raw'         => 'begin 1 First block'
        },
        'TAP::Parser::Result::Begin'
    ),
    bless(
        {   'explanation' => '',
            'context'     => [
                '1'
            ],
            'todo_list'     => [],
            'directive'     => '',
            'type'          => 'plan',
            'tests_planned' => 3,
            'raw'           => '1..3'
        },
        'TAP::Parser::Result::Plan'
    ),
    bless(
        {   'ok'          => 'ok',
            'explanation' => '',
            'context'     => [
                '1'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => 'FB: 1',
            'test_num'    => '1',
            'raw'         => 'ok 1 FB: 1'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'ok'          => 'not ok',
            'explanation' => '',
            'context'     => [
                '1'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => 'FB: 2',
            'test_num'    => '2',
            'raw'         => 'not ok 2 FB: 2'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'ok'          => 'ok',
            'explanation' => '',
            'context'     => [
                '1'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => 'FB: 3',
            'test_num'    => '3',
            'raw'         => 'ok 3 FB: 3'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'ok'          => 'not ok',
            'explanation' => '',
            'type'        => 'test',
            'directive'   => '',
            'description' => 'FB: Summary',
            'test_num'    => '1',
            'raw'         => 'not ok 1 FB: Summary'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'type'        => 'test',
            'directive'   => '',
            'description' => 'A test',
            'test_num'    => '2',
            'raw'         => 'ok 2 A test'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'type'        => 'test',
            'directive'   => '',
            'description' => 'and another',
            'test_num'    => '3',
            'raw'         => 'ok 3 and another'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'type'        => 'begin',
            'description' => 'Second block',
            'test_num'    => '4',
            'raw'         => 'begin 4 Second block'
        },
        'TAP::Parser::Result::Begin'
    ),
    bless(
        {   'context'     => ['4'],
            'type'        => 'begin',
            'description' => 'Nested block',
            'test_num'    => '1',
            'raw'         => 'begin 1 Nested block'
        },
        'TAP::Parser::Result::Begin'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'context'     => [
                '4',
                '1'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => 'NB: 1',
            'test_num'    => '1',
            'raw'         => 'ok 1 NB: 1'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'context'     => [
                '4',
                '1'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => 'NB: 2',
            'test_num'    => '2',
            'raw'         => 'ok 2 NB: 2'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'explanation' => '',
            'context'     => [
                '4',
                '1'
            ],
            'todo_list'     => [],
            'directive'     => '',
            'type'          => 'plan',
            'tests_planned' => 2,
            'raw'           => '1..2'
        },
        'TAP::Parser::Result::Plan'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'context'     => [
                '4'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => 'NB: Summary',
            'test_num'    => '1',
            'raw'         => 'ok 1 NB: Summary'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'context'     => ['4'],
            'type'        => 'begin',
            'description' => '',
            'test_num'    => '2',
            'raw'         => 'begin 2'
        },
        'TAP::Parser::Result::Begin'
    ),
    bless(
        {   'explanation' => '',
            'context'     => [
                '4',
                '2'
            ],
            'todo_list'     => [],
            'directive'     => 'SKIP',
            'type'          => 'plan',
            'tests_planned' => 0,
            'raw'           => '1..0 # SKIP'
        },
        'TAP::Parser::Result::Plan'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'context'     => [
                '4'
            ],
            'type'        => 'test',
            'directive'   => '',
            'description' => '',
            'test_num'    => '2',
            'raw'         => 'ok 2'
        },
        'TAP::Parser::Result::Test'
    ),
    bless(
        {   'explanation' => '',
            'context'     => [
                '4'
            ],
            'todo_list'     => [],
            'directive'     => '',
            'type'          => 'plan',
            'tests_planned' => 2,
            'raw'           => '1..2'
        },
        'TAP::Parser::Result::Plan'
    ),
    bless(
        {   'ok'          => 'ok',
            'unplanned'   => 1,
            'explanation' => '',
            'type'        => 'test',
            'directive'   => '',
            'description' => 'SB: Summary',
            'test_num'    => '4',
            'raw'         => 'ok 4 SB: Summary'
        },
        'TAP::Parser::Result::Test'
    )
);

is_deeply \@results, \@expect, "results match";

