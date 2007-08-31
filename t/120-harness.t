#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More;
use IO::Capture;

END {

    # we push this at the end because there are annoying problem with other
    # modules which check $^O
    my @warnings;
    local $^O = 'MSWin32';
    $SIG{__WARN__} = sub { @warnings = shift };
    delete $INC{'TAP/Harness/Color.pm'};
    use_ok 'TAP::Harness::Color';
    ok my $harness = TAP::Harness::Color->new,
      '... and loading it on windows should succeed';
    isa_ok $harness, 'TAP::Harness', '... but the object it returns';

    ok( grep( qr/^Color test output disabled on Windows/, @warnings ),
        'Using TAP::Harness::Color on Windows should disable colored output'
    );

}

use TAP::Harness;
use TAP::Harness::Color;

my @HARNESSES = 'TAP::Harness';
my $PLAN      = 73;

if ( TAP::Harness::Color->can_color ) {
    push @HARNESSES, 'TAP::Harness::Color';
    $PLAN += 45;
}

plan tests => $PLAN;

# note that this test will always pass when run through 'prove'
ok $ENV{HARNESS_ACTIVE},  'HARNESS_ACTIVE env variable should be set';
ok $ENV{HARNESS_VERSION}, 'HARNESS_VERSION env variable should be set';

foreach my $HARNESS (@HARNESSES) {

    #foreach my $HARNESS ( () ) {   # XXX
    can_ok $HARNESS, 'new';

    eval { $HARNESS->new( { no_such_key => 1 } ) };
    like $@, qr/\QUnknown arguments to TAP::Harness::new (no_such_key)/,
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
            is_deeply scalar $harness->$property(), $value,
              $test->{test_name};
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
    local *TAP::Harness::_should_show_count = sub {0};
    local *TAP::Harness::output = sub {
        my $self = shift;
        push @output => grep { $_ ne '' }
          map {
            local $_ = $_;
            chomp;
            trim($_)
          } @_;
    };
    my $harness            = TAP::Harness->new( { verbose      => 1 } );
    my $harness_whisper    = TAP::Harness->new( { quiet        => 1 } );
    my $harness_mute       = TAP::Harness->new( { really_quiet => 1 } );
    my $harness_directives = TAP::Harness->new( { directives   => 1 } );
    my $harness_failures   = TAP::Harness->new( { failures     => 1 } );

    can_ok $harness, 'runtests';

    # normal tests in verbose mode

    ok my $aggregate = _runtests( $harness, 't/source_tests/harness' ),
      '... runtests returns the aggregate';

    isa_ok $aggregate, 'TAP::Parser::Aggregator';

    chomp(@output);

    my @expected = (
        't/source_tests/harness....',
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

    # normal tests in quiet mode

    @output = ();
    _runtests( $harness_whisper, 't/source_tests/harness' );

    chomp(@output);
    @expected = (
        't/source_tests/harness....',
        'ok',
        'All tests successful.',
    );

    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=1,  \d+ wallclock secs/;

    is_deeply \@output, \@expected, '... and the output should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    # normal tests in really_quiet mode

    @output = ();
    _runtests( $harness_mute, 't/source_tests/harness' );

    chomp(@output);
    @expected = (
        'All tests successful.',
    );

    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=1,  \d+ wallclock secs/;

    is_deeply \@output, \@expected, '... and the output should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    # normal tests with failures

    @output = ();
    _runtests( $harness, 't/source_tests/harness_failure' );

    my @summary = @output[ 5 .. ( $#output - 1 ) ];
    @output   = @output[ 0 .. 4 ];
    @expected = (
        't/source_tests/harness_failure....',
        '1..2',
        'ok 1 - this is a test',
        'not ok 2 - this is another test',
        'Failed 1/2 subtests',
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

    # quiet tests with failures

    @output = ();
    _runtests( $harness_whisper, 't/source_tests/harness_failure' );

    pop @output;    # get rid of summary line
    @expected = (
        't/source_tests/harness_failure....',
        'Failed 1/2 subtests',
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed tests:',
        '2',
    );
    is_deeply \@output, \@expected,
      '... and failing test output should be correct';

    # really quiet tests with failures

    @output = ();
    _runtests( $harness_mute, 't/source_tests/harness_failure' );

    pop @output;    # get rid of summary line
    @expected = (
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed tests:',
        '2',
    );
    is_deeply \@output, \@expected,
      '... and failing test output should be correct';

    # only show directives

    @output = ();
    _runtests( $harness_directives, 't/source_tests/harness_directives' );

    chomp(@output);

    @expected = (
        't/source_tests/harness_directives....',
        'not ok 2 - we have a something # TODO some output',
        "ok 3 houston, we don't have liftoff # SKIP no funding",
        'ok',
        'All tests successful.',
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_directives (Wstat: 0 Tests: 3 Failed: 0)',
        'Tests skipped:',
        '3',
    );

    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=3,  \d+ wallclock secs/;

    is_deeply \@output, \@expected, '... and the output should be correct';
    like $summary, $expected_summary,
      '... and the report summary should look correct';

    # normal tests with bad tap

    # install callback handler
    my $parser;
    my $callback_count = 0;
    $harness->callback(
        made_parser => sub {
            $parser = shift;
            $callback_count++;
        }
    );

    @output = ();
    _runtests( $harness, 't/source_tests/harness_badtap' );
    chomp(@output);

    @output = map { trim($_) } @output;
    @summary  = @output[ 6 .. ( $#output - 1 ) ];
    @output   = @output[ 0 .. 5 ];
    @expected = (
        't/source_tests/harness_badtap....',
        '1..2',
        'ok 1 - this is a test',
        'not ok 2 - this is another test',
        '1..2',
        'Failed 1/2 subtests',
    );
    is_deeply \@output, \@expected,
      '... and failing test output should be correct';
    @expected_summary = (
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_badtap (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed tests:',
        '2',
        'Parse errors: More than one plan found in TAP output'
    );
    is_deeply \@summary, \@expected_summary,
      '... and the badtap summary should also be correct';

    cmp_ok( $callback_count, '==', 1, 'callback called once' );
    isa_ok $parser, 'TAP::Parser';

    # coverage testing for _should_show_failures
    # only show failures

    @output = ();
    _runtests( $harness_failures, 't/source_tests/harness_failure' );

    chomp(@output);

    @expected = (
        't/source_tests/harness_failure....',
        'not ok 2 - this is another test',
        'Failed 1/2 subtests',
        'Test Summary Report',
        '-------------------',
        't/source_tests/harness_failure (Wstat: 0 Tests: 2 Failed: 1)',
        'Failed tests:',
        '2',
    );

    $summary          = pop @output;
    $expected_summary = qr/^Files=1, Tests=2,  \d+ wallclock secs/;

    is_deeply \@output, \@expected, '... and the output should be correct';

    #XXXX
}

# make sure we can exec something ... anything!
SKIP: {

    my $cat = '/bin/cat';
    unless ( -e $cat ) {
        skip "no '$cat'", 1;
    }

    my $capture = IO::Capture->new_handle;
    my $harness = TAP::Harness->new(
        {   verbose      => 1,
            really_quiet => 1,
            really_quiet => 1,
            stdout       => $capture,
            exec         => [$cat],
        }
    );

    eval { _runtests( $harness, 't/data/catme.1' ) };

    my @output = tied($$capture)->dump;
    pop @output;    # get rid of summary line
    my $answer = pop @output;
    is( $answer, "All tests successful.\n", 'cat meows' );
}

# catches "exec accumulates arguments" issue (r77)
{
    my $capture = IO::Capture->new_handle;
    my $harness = TAP::Harness->new(
        {   verbose      => 1,
            really_quiet => 1,
            stdout       => $capture,
            exec         => [$^X]
        }
    );

    _runtests(
        $harness,
        't/source_tests/harness_complain',    # will get mad if run with args
        't/source_tests/harness',
    );

    my @output = tied($$capture)->dump;
    pop @output;                              # get rid of summary line
    is( $output[-1], "All tests successful.\n", 'No exec accumulation' );
}

sub trim {
    $_[0] =~ s/^\s+|\s+$//g;
    return $_[0];
}

sub liblist {
    return [ map { '-I' . File::Spec->rel2abs($_) } @_ ];
}

sub get_arg_sets {

    # keys are keys to new()
    return {
        lib => {
            in        => 'lib',
            out       => liblist('lib'),
            test_name => '... a single lib switch should be correct'
        },
        verbose => {
            in        => 1,
            out       => 1,
            test_name => '... and we should be able to set verbose to true'
        },
      },
      { lib => {
            in        => [ 'lib',        't' ],
            out       => liblist( 'lib', 't' ),
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
            in  => 1,
            out => 1,
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

sub _runtests {
    my ( $harness, @tests ) = @_;
    local $ENV{PERL_TEST_HARNESS_DUMP_TAP} = 0;
    my $aggregate = $harness->runtests(@tests);
    return $aggregate;
}
