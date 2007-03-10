#!/usr/bin/perl -w

use strict;

use lib 'lib';

use Test::More tests => 132;

# these tests cannot be run from the t/ directory due to checking for the
# existence of execrc

END {

    # we push this at the end because there are annoying problem with other
    # modules which check $^O
    my @warnings;
    local $^O = 'MSWin32';
    $SIG{__WARN__} = sub { @warnings = shift };
    delete $INC{'TAPx/Harness/Color.pm'};
    use_ok 'TAPx::Harness::Color';
    ok my $harness = TAPx::Harness::Color->new,
      '... and loading it on windows should succeed';
    isa_ok $harness, 'TAPx::Harness', '... but the object it returns';

    ok grep( {qr/^Color test output disabled on Windows/} @warnings ),
      'Using TAPx::Harness::Color on Windows should disable colored output';

}

use TAPx::Harness;
use TAPx::Harness::Color;

# note that this test will always pass when run through 'prove'
ok $ENV{HARNESS_ACTIVE},  'HARNESS_ACTIVE env variable should be set';
ok $ENV{HARNESS_VERSION}, 'HARNESS_VERSION env variable should be set';

foreach my $HARNESS (qw<TAPx::Harness TAPx::Harness::Color>) {
#foreach my $HARNESS ( () ) {   # XXX
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
    local *TAPx::Harness::_should_show_count = sub {0};
    local *TAPx::Harness::output = sub {
        my $self = shift;
        push @output => grep { $_ ne '' }
          map {
            local $_ = $_;
            chomp;
            trim($_)
          } @_;
    };
    my $harness            = TAPx::Harness->new( { verbose      => 1 } );
    my $harness_whisper    = TAPx::Harness->new( { quiet        => 1 } );
    my $harness_mute       = TAPx::Harness->new( { really_quiet => 1 } );
    my $harness_directives = TAPx::Harness->new( { directives   => 1 } );
    can_ok $harness, 'runtests';

    # normal tests in verbose mode

    $harness->runtests('t/source_tests/harness');

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
    $harness_whisper->runtests('t/source_tests/harness');

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
    $harness_mute->runtests('t/source_tests/harness');

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
    $harness->runtests('t/source_tests/harness_failure');

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
    $harness_whisper->runtests('t/source_tests/harness_failure');

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
    $harness_mute->runtests('t/source_tests/harness_failure');

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
    $harness_directives->runtests('t/source_tests/harness_directives');

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
    $harness->runtests('t/source_tests/harness_badtap');
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
    isa_ok $parser, 'TAPx::Parser';
}

{
    my @output;
    local $^W;
    local *TAPx::Harness::_should_show_count = sub {0};
    local *TAPx::Harness::output = sub {
        my $self = shift;
        push @output => grep { $_ ne '' }
          map {
            local $_ = $_;
            chomp;
            trim($_)
          } @_;
    };
    my $harness = TAPx::Harness->new(
        {   verbose => 1,
            exec    => [$^X]
        }
    );

    $harness->runtests(
        't/source_tests/harness_complain',    # will get mad if run with args
        't/source_tests/harness',
    );

    chomp(@output);
    pop @output;                              # get rid of summary line
    is( $output[-1], 'All tests successful.', 'No exec accumulation' );
}

{

    # make sure execrc parsing is solid (internals test)
    my $harness = TAPx::Harness->new;
    ok !$harness->exec, 'exec() should not be set when the harness is new';
    my %execrc = %{ $harness->_execrc };
    is_deeply \%execrc, { exact => {}, regex => {} },
         '... nor should execrc';

    can_ok $harness, '_read_execrc';
    $harness->execrc('t/data/execrc');
    ok $harness->_read_execrc, '... and reading the execrc should succeed';

    can_ok $harness, '_get_executable';
    is_deeply $harness->_get_executable('t/some_test.t'),
      [ '/usr/bin/perl',
        '-wT',
        't/some_test.t'
      ],
      '... and it should return default results for unmatcheable test names';

    is_deeply $harness->_get_executable('t/ruby.t'),
      [ '/usr/bin/ruby',
        't/ruby.t'
      ],
      '... but an exact match should return a specific executable';
    is_deeply $harness->_get_executable('http://www.google.com/'),
      [ '/usr/bin/perl',
        '-w',
        'bin/test_html.pl',
        'http://www.google.com/',
      ],
      '... even if we match something which is not a file';
    is_deeply $harness->_get_executable('t/some_customer.t'),
      [ '/usr/bin/perl',
        '-w',
        't/some_customer.t'
      ],
      '... and regexes should work for specifying tests';
    is_deeply $harness->_get_executable('t/customer.t'),
      [ '/usr/bin/perl',
        't/customer.t'
      ],
      '... but an exact match will override a regex test';
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
