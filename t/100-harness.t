#!/usr/bin/perl -w

use strict;

use lib 'lib';

use Test::More 'no_plan';    # tests => 30;
use TAPx::Harness;
use TAPx::Harness::Color;

# note that this test will always pass when run through 'prove'
ok $ENV{HARNESS_ACTIVE},  'HARNESS_ACTIVE env variable should be set';
ok $ENV{HARNESS_VERSION}, 'HARNESS_VERSION env variable should be set';

# these tests cannot be run from the t/ directory due to checking for the
# existence of execrc

foreach my $HARNESS (qw<TAPx::Harness TAPx::Harness::Color>) {
    can_ok $HARNESS, 'new';

    eval { $HARNESS->new( { no_such_key => 1 } ) };
    like $@, qr/\QUnknown arguments to TAPx::Harness::new (no_such_key)/,
      '... and calling it with bad keys should fail';

    eval { $HARNESS->new( { lib => 'aint_no_such_lib' } ) };
    ok my $error = $@,
      '... and calling it with a non-existent lib should fail';
    like $error, qr/^\QNo such lib (aint_no_such_lib)/,
      '... with an appropriate error message';

    eval { $HARNESS->new( { lib => [qw/bad_lib_1 bad_lib_2/] } ) };
    ok $error = $@, '... and calling it with non-existent libs should fail';
    like $error, qr/^\QNo such libs (bad_lib_1 bad_lib_2)/,
      '... with an appropriate error message';

    eval { $HARNESS->new( { execrc => 'aint_no_such_execrc' } ) };
    ok $error = $@,
      '... and calling it with a non-existent execrc should fail';
    like $error, qr/^\QCannot find execrc (aint_no_such_execrc)/,
      '... with an appropriate error message';

    ok my $harness = $HARNESS->new,
      'Calling new() without arguments should succeed';

    foreach my $test_args ( get_arg_sets() ) {
        my %args = %$test_args;
        foreach my $key ( keys %args ) {
            $args{$key} = $args{$key}{in};
        }
        ok my $harness = $HARNESS->new( {%args} ),
          'Calling new() with valid arguments should succeed';
        isa_ok $harness, $HARNESS, '... and the object it returns';

        while ( my ( $property, $test ) = each %$test_args ) {
            my $value = $test->{out};
            can_ok $harness, $property;
            is_deeply scalar $harness->$property, $value, $test->{test_name};
        }
    }
    foreach my $method_data ( harness_methods() ) {
        my ( $method, $data ) = %$method_data;
        can_ok $harness, $method;
        is_deeply [ $harness->$method( $data->{in}->() ) ],
          [ $data->{out}->() ], $data->{test_name};
    }
}

{
    my @output;
    local $^W;
    local *TAPx::Harness::output = sub {
        my $self = shift;
        push @output => @_;
    };
    my $harness = TAPx::Harness->new( { verbose => 1 } );
    can_ok $harness, 'runtests';
    $harness->runtests('t/source_tests/harness');

    chomp(@output);

    my @expected = (
        't/source_tests/harness....',
        '',
        '1..1',
        'ok 1 - this is a test',
        'ok',
        'All tests successful.',
    );

    my $summary          = pop @output;
    my $expected_summary = qr/^Files=1, Tests=1,  \d+ wallclock secs/;

    is_deeply \@output, \@expected, '... and the output should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    @output = ();
    $harness->runtests('t/source_tests/harness_failure');
    chomp(@output);

    @output = map { trim($_) } @output;
    my @summary = @output[ 7 .. 11 ];
    @output   = @output[ 0 .. 6 ];
    @expected = (
        't/source_tests/harness_failure....',
        '',
        '1..2',
        'ok 1 - this is a test',
        'not ok 2 - this is another test',
        'Failed 1/2 tests',
        '',
    );
    is_deeply \@output, \@expected,
      '... and failing test output should be correct';
    my @expected_summary = (
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed tests:',
        '2',
    );
    is_deeply \@summary, \@expected_summary,
      '... and the failure summary should also be correct';
}

sub trim {
    $_[0] =~ s/^\s+|\s+$//g;
    return $_[0];
}

sub get_arg_sets {

    # keys are keys to new()
    return {
        lib => {
            in        => 'lib',
            out       => ['-Ilib'],
            test_name => '... a single lib switch should be correct'
        },
        verbose => {
            in        => 1,
            out       => 1,
            test_name => '... and we should be able to set verbose to true'
        },
      },
      { lib => {
            in        => [ 'lib',   't' ],
            out       => [ '-Ilib', '-It' ],
            test_name => '... multiple lib switches should be correct'
        },
        verbose => {
            in        => 0,
            out       => 0,
            test_name => '... and we should be able to set verbose to false'
        },
      },
      { switches => {
            in  => [ '-T', '-w', '-T' ],
            out => [ '-T', '-w' ],
            test_name => '... duplicate switches should be omitted',
        },
        failures => {
            in        => 1,
            out       => 1,
            test_name => '... and we should be able to set failures to true',
        },
        quiet => {
            in        => 1,
            out       => 1,
            test_name => '... and we should be able to set quiet to false'
        },
      },

      { really_quiet => {
            in        => 1,
            out       => 1,
            test_name =>
              '... and we should be able to set really_quiet to true',
        },
        exec => {
            in        => $^X,
            out       => $^X,
            test_name => '... and we should be able to set the executable',
        },
      },
      { switches => {
            in        => 'T',
            out       => ['-T'],
            test_name => '... leading dashes (-) on switches are optional',
        },
      },
      { switches => {
            in        => '-T',
            out       => ['-T'],
            test_name => '... we should be able to set switches',
        },
        failures => {
            in        => 1,
            out       => 1,
            test_name => '... and we should be able to set failures to true'
        },
        execrc => {
            in        => 't/data/execrc',
            out       => 't/data/execrc',
            test_name => '... and we should be able to set execrc'
        },
      };
}

sub harness_methods {
    return {
        range => {
            in  => sub {qw/2 7 1 3 10 9/},
            out => sub {qw/1-3 7 9-10/},
            test_name => '... and it should return numbers as ranges'
        },
        balanced_range => {
            in  => sub { 7,        qw/2 7 1 3 10 9/ },
            out => sub { '1-3, 7', '9-10' },
            test_name => '... and it should return numbers as ranges'
        },
    };
}
