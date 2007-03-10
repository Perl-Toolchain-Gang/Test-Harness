package TAP::Harness::Compatible;

require 5.00405;

use TAP::Harness;
use TAP::Parser::Aggregator;

#use TAP::Harness::Compatible::Straps;
use Exporter;
use Benchmark;
use Config;
use strict;

# TODO: Emulate at least some of these
use vars qw(
  $VERSION
  @ISA @EXPORT @EXPORT_OK
  $Verbose $Switches $Debug
  $verbose $switches $debug
  $Columns
  $Directives
  $Timer
  $ML $Last_ML_Print
  $Strap
  $has_time_hires
);

BEGIN {
    eval q{use Time::HiRes 'time'};
    $has_time_hires = !$@;
}

=head1 NAME

TAP::Harness::Compatible - Run Perl standard test scripts with statistics

=head1 VERSION

Version 0.51

=cut

$VERSION = '0.51';

# Backwards compatibility for exportable variable names.
*verbose  = *Verbose;
*switches = *Switches;
*debug    = *Debug;

#
# $ENV{HARNESS_ACTIVE} = 1;
# $ENV{HARNESS_VERSION} = $VERSION;
#
# END {
#     # For VMS.
#     delete $ENV{HARNESS_ACTIVE};
#     delete $ENV{HARNESS_VERSION};
# }
#
# my $Files_In_Dir = $ENV{HARNESS_FILELEAK_IN_DIR};
#
# # Stolen from Params::Util
# sub _CLASS {
#     (defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*$/s) ? $_[0] : undef;
# }
#
# # Strap Overloading
# if ( $ENV{HARNESS_STRAPS_CLASS} ) {
#     die 'Set HARNESS_STRAP_CLASS, singular, not HARNESS_STRAPS_CLASS';
# }
# my $HARNESS_STRAP_CLASS  = $ENV{HARNESS_STRAP_CLASS} || 'TAP::Harness::Compatible::Straps';
# if ( $HARNESS_STRAP_CLASS =~ /\.pm$/ ) {
#     # "Class" is actually a filename, that should return the
#     # class name as its true return value.
#     $HARNESS_STRAP_CLASS = require $HARNESS_STRAP_CLASS;
#     if ( !_CLASS($HARNESS_STRAP_CLASS) ) {
#         die "HARNESS_STRAP_CLASS '$HARNESS_STRAP_CLASS' is not a valid class name";
#     }
# }
# else {
#     # It is a class name within the current @INC
#     if ( !_CLASS($HARNESS_STRAP_CLASS) ) {
#         die "HARNESS_STRAP_CLASS '$HARNESS_STRAP_CLASS' is not a valid class name";
#     }
#     eval "require $HARNESS_STRAP_CLASS";
#     die $@ if $@;
# }
# if ( !$HARNESS_STRAP_CLASS->isa('TAP::Harness::Compatible::Straps') ) {
#     die "HARNESS_STRAP_CLASS '$HARNESS_STRAP_CLASS' must be a TAP::Harness::Compatible::Straps subclass";
# }
#
# $Strap = $HARNESS_STRAP_CLASS->new;
#
# sub strap { return $Strap };
#

@ISA       = ('Exporter');
@EXPORT    = qw(&runtests);
@EXPORT_OK = qw(&execute_tests $verbose $switches);

$Verbose = $ENV{HARNESS_VERBOSE} || 0;
$Debug   = $ENV{HARNESS_DEBUG}   || 0;
$Switches = '-w';
$Columns = $ENV{HARNESS_COLUMNS} || $ENV{COLUMNS} || 80;
$Columns--;    # Some shells have trouble with a full line of text.
$Timer = $ENV{HARNESS_TIMER} || 0;

=head1 SYNOPSIS

  use TAP::Harness::Compatible;

  runtests(@test_files);

=head1 DESCRIPTION

B<STOP!> If all you want to do is write a test script, consider
using Test::Simple.  TAP::Harness::Compatible is the module that reads the
output from Test::Simple, Test::More and other modules based on
Test::Builder.  You don't need to know about TAP::Harness::Compatible to use
those modules.

TAP::Harness::Compatible runs tests and expects output from the test in a
certain format.  That format is called TAP, the Test Anything
Protocol.  It is defined in L<TAP::Harness::Compatible::TAP>.

C<TAP::Harness::Compatible::runtests(@tests)> runs all the testscripts named
as arguments and checks standard output for the expected strings
in TAP format.

The F<prove> utility is a thin wrapper around TAP::Harness::Compatible.

=head2 Taint mode

TAP::Harness::Compatible will honor the C<-T> or C<-t> in the #! line on your
test files.  So if you begin a test with:

    #!perl -T

the test will be run with taint mode on.

=head2 Configuration variables.

These variables can be used to configure the behavior of
TAP::Harness::Compatible.  They are exported on request.

=over 4

=item C<$TAP::Harness::Compatible::Verbose>

The package variable C<$TAP::Harness::Compatible::Verbose> is exportable and can be
used to let C<runtests()> display the standard output of the script
without altering the behavior otherwise.  The F<prove> utility's C<-v>
flag will set this.

=item C<$TAP::Harness::Compatible::switches>

The package variable C<$TAP::Harness::Compatible::switches> is exportable and can be
used to set perl command line options used for running the test
script(s). The default value is C<-w>. It overrides C<HARNESS_PERL_SWITCHES>.

=item C<$TAP::Harness::Compatible::Timer>

If set to true, and C<Time::HiRes> is available, print elapsed seconds
after each test file.

=back


=head2 Failure

When tests fail, analyze the summary report:

  t/base..............ok
  t/nonumbers.........ok
  t/ok................ok
  t/test-harness......ok
  t/waterloo..........dubious
          Test returned status 3 (wstat 768, 0x300)
  DIED. FAILED tests 1, 3, 5, 7, 9, 11, 13, 15, 17, 19
          Failed 10/20 tests, 50.00% okay
  Failed Test  Stat Wstat Total Fail  List of Failed
  ---------------------------------------------------------------
  t/waterloo.t    3   768    20   10  1 3 5 7 9 11 13 15 17 19
  Failed 1/5 test scripts, 80.00% okay. 10/44 subtests failed, 77.27% okay.

Everything passed but F<t/waterloo.t>.  It failed 10 of 20 tests and
exited with non-zero status indicating something dubious happened.

The columns in the summary report mean:

=over 4

=item B<Failed Test>

The test file which failed.

=item B<Stat>

If the test exited with non-zero, this is its exit status.

=item B<Wstat>

The wait status of the test.

=item B<Total>

Total number of tests expected to run.

=item B<Fail>

Number which failed, either from "not ok" or because they never ran.

=item B<List of Failed>

A list of the tests which failed.  Successive failures may be
abbreviated (ie. 15-20 to indicate that tests 15, 16, 17, 18, 19 and
20 failed).

=back


=head1 FUNCTIONS

The following functions are available.

=head2 runtests( @test_files )

This runs all the given I<@test_files> and divines whether they passed
or failed based on their output to STDOUT (details above).  It prints
out each individual test which failed along with a summary report and
a how long it all took.

It returns true if everything was ok.  Otherwise it will C<die()> with
one of the messages in the DIAGNOSTICS section.

=cut

sub runtests {
    my @tests = @_;

    my $harness   = _new_harness();
    my $aggregate = TAP::Parser::Aggregator->new();

    my $results = $harness->aggregate_tests( $aggregate, @tests );

    $harness->summary($results);

    my $total  = $aggregate->total;
    my $passed = $aggregate->passed;

    return $total && $total == $passed;
}

sub _canon {
    my @list   = sort { $a <=> $b } @_;
    my @ranges = ();
    my $count  = scalar @list;
    my $pos    = 0;

    while ( $pos < $count ) {
        my $end = $pos + 1;
        $end++ while $end < $count && $list[$end] <= $list[ $end - 1 ] + 1;
        push @ranges, ( $end == $pos + 1 )
          ? $list[$pos]
          : join( '-', $list[$pos], $list[ $end - 1 ] );
        $pos = $end;
    }

    return join( ' ', @ranges );
}

sub _new_harness {

    # TODO: lib? switches?
    my $args = {
        verbose    => $Verbose,
        timer      => $Timer,
        directives => $Directives,
    };

    return TAP::Harness->new($args);
}

sub _check_sequence {
    my @list = @_;
    my $prev;
    while ( my $next = shift @list ) {
        return if defined $prev && $next <= $prev;
        $prev = $next;
    }

    return 1;
}

sub execute_tests {
    my %args = @_;

    # TODO: Handle out option

    my $harness   = _new_harness();
    my $aggregate = TAP::Parser::Aggregator->new();

    my %tot = (
        bonus       => 0,
        max         => 0,
        ok          => 0,
        bad         => 0,
        good        => 0,
        files       => 0,
        tests       => 0,
        sub_skipped => 0,
        todo        => 0,
        skipped     => 0,
        bench       => undef,
    );

    # Install a callback so we get to see any plans the
    # harness executes.
    $harness->callback(
        made_parser => sub {
            my $parser = shift;
            $parser->callback(
                plan => sub {
                    my $plan = shift;
                    if ( $plan->directive eq 'SKIP' ) {
                        $tot{skipped}++;
                    }
                }
            );
        }
    );

    my $results = $harness->aggregate_tests( $aggregate, @{ $args{tests} } );

    $tot{bench} = timediff( $results->{end}, $results->{start} );

    # TODO: Work out the circumstances under which the files
    # and tests totals can differ.
    $tot{files} = $tot{tests} = @{ $results->{tests} };

    my %failedtests = ();
    my %todo_passed = ();

    for my $test ( @{ $results->{tests} } ) {
        my ($parser) = $aggregate->parsers($test);

        my @failed = $parser->failed;

        my $wstat         = $parser->wait;
        my $estat         = $parser->exit;
        my $planned       = $parser->tests_planned;
        my @errors        = $parser->parse_errors;
        my $passed        = $parser->passed;
        my $actual_passed = $parser->actual_passed;

        my $ok_seq = _check_sequence( $parser->actual_passed );

        # Duplicate exit, wait status semantics of old version
        $estat ||= '' unless $wstat;
        $wstat ||= '';

        $tot{max} += ( $planned || 0 );
        $tot{bonus} += $parser->todo_passed;
        $tot{ok} += $passed > $actual_passed ? $passed : $actual_passed;
        $tot{sub_skipped} += $parser->skipped;
        $tot{todo}        += $parser->todo;

        if ( @failed || $estat || @errors ) {
            $tot{bad}++;

            my $huh_planned = $planned ? undef: '??';
            my $huh_errors  = $ok_seq  ? undef: '??';

            $failedtests{$test} = {
                'canon' => $huh_planned
                  || $huh_errors
                  || _canon(@failed)
                  || '??',
                'estat'  => $estat,
                'failed' => $huh_planned || $huh_errors || scalar @failed,
                'max' => $huh_planned || $planned,
                'name'  => $test,
                'wstat' => $wstat
            };
        }
        else {
            $tot{good}++;
        }

        my @todo = $parser->todo_passed;
        if (@todo) {
            $todo_passed{$test} = {
                'canon'  => _canon(@todo),
                'estat'  => $estat,
                'failed' => scalar @todo,
                'max'    => scalar $parser->todo,
                'name'   => $test,
                'wstat'  => $wstat
            };
        }
    }

    return ( \%tot, \%failedtests, \%todo_passed );
}

=head2 execute_tests( tests => \@test_files, out => \*FH )

Runs all the given C<@test_files> (just like C<runtests()>) but
doesn't generate the final report.  During testing, progress
information will be written to the currently selected output
filehandle (usually C<STDOUT>), or to the filehandle given by the
C<out> parameter.  The I<out> is optional.

Returns a list of two values, C<$total> and C<$failed>, describing the
results.  C<$total> is a hash ref summary of all the tests run.  Its
keys and values are this:

    bonus           Number of individual todo tests unexpectedly passed
    max             Number of individual tests ran
    ok              Number of individual tests passed
    sub_skipped     Number of individual tests skipped
    todo            Number of individual todo tests

    files           Number of test files ran
    good            Number of test files passed
    bad             Number of test files failed
    tests           Number of test files originally given
    skipped         Number of test files skipped

If C<< $total->{bad} == 0 >> and C<< $total->{max} > 0 >>, you've
got a successful test.

C<$failed> is a hash ref of all the test scripts that failed.  Each key
is the name of a test script, each value is another hash representing
how that script failed.  Its keys are these:

    name        Name of the test which failed
    estat       Script's exit value
    wstat       Script's wait status
    max         Number of individual tests
    failed      Number which failed
    canon       List of tests which failed (as string).

C<$failed> should be empty if everything passed.

=cut

1;
__END__


=head1 EXPORT

C<&runtests> is exported by TAP::Harness::Compatible by default.

C<&execute_tests>, C<$verbose>, C<$switches> and C<$debug> are
exported upon request.

=head1 DIAGNOSTICS

=over 4

=item C<All tests successful.\nFiles=%d,  Tests=%d, %s>

If all tests are successful some statistics about the performance are
printed.

=item C<FAILED tests %s\n\tFailed %d/%d tests, %.2f%% okay.>

For any single script that has failing subtests statistics like the
above are printed.

=item C<Test returned status %d (wstat %d)>

Scripts that return a non-zero exit status, both C<$? E<gt>E<gt> 8>
and C<$?> are printed in a message similar to the above.

=item C<Failed 1 test, %.2f%% okay. %s>

=item C<Failed %d/%d tests, %.2f%% okay. %s>

If not all tests were successful, the script dies with one of the
above messages.

=item C<FAILED--Further testing stopped: %s>

If a single subtest decides that further testing will not make sense,
the script dies with this message.

=back

=head1 ENVIRONMENT VARIABLES THAT TEST::HARNESS SETS

TAP::Harness::Compatible sets these before executing the individual tests.

=over 4

=item C<HARNESS_ACTIVE>

This is set to a true value.  It allows the tests to determine if they
are being executed through the harness or by any other means.

=item C<HARNESS_VERSION>

This is the version of TAP::Harness::Compatible.

=back

=head1 ENVIRONMENT VARIABLES THAT AFFECT TEST::HARNESS

=over 4

=item C<HARNESS_COLUMNS>

This value will be used for the width of the terminal. If it is not
set then it will default to C<COLUMNS>. If this is not set, it will
default to 80. Note that users of Bourne-sh based shells will need to
C<export COLUMNS> for this module to use that variable.

=item C<HARNESS_COMPILE_TEST>

When true it will make harness attempt to compile the test using
C<perlcc> before running it.

B<NOTE> This currently only works when sitting in the perl source
directory!

=item C<HARNESS_DEBUG>

If true, TAP::Harness::Compatible will print debugging information about itself as
it runs the tests.  This is different from C<HARNESS_VERBOSE>, which prints
the output from the test being run.  Setting C<$TAP::Harness::Compatible::Debug> will
override this, or you can use the C<-d> switch in the F<prove> utility.

=item C<HARNESS_FILELEAK_IN_DIR>

When set to the name of a directory, harness will check after each
test whether new files appeared in that directory, and report them as

  LEAKED FILES: scr.tmp 0 my.db

If relative, directory name is with respect to the current directory at
the moment runtests() was called.  Putting absolute path into 
C<HARNESS_FILELEAK_IN_DIR> may give more predictable results.

=item C<HARNESS_NOTTY>

When set to a true value, forces it to behave as though STDOUT were
not a console.  You may need to set this if you don't want harness to
output more frequent progress messages using carriage returns.  Some
consoles may not handle carriage returns properly (which results in a
somewhat messy output).

=item C<HARNESS_PERL>

Usually your tests will be run by C<$^X>, the currently-executing Perl.
However, you may want to have it run by a different executable, such as
a threading perl, or a different version.

If you're using the F<prove> utility, you can use the C<--perl> switch.

=item C<HARNESS_PERL_SWITCHES>

Its value will be prepended to the switches used to invoke perl on
each test.  For example, setting C<HARNESS_PERL_SWITCHES> to C<-W> will
run all tests with all warnings enabled.

=item C<HARNESS_TIMER>

Setting this to true will make the harness display the number of
milliseconds each test took.  You can also use F<prove>'s C<--timer>
switch.

=item C<HARNESS_VERBOSE>

If true, TAP::Harness::Compatible will output the verbose results of running
its tests.  Setting C<$TAP::Harness::Compatible::verbose> will override this,
or you can use the C<-v> switch in the F<prove> utility.

If true, TAP::Harness::Compatible will output the verbose results of running
its tests.  Setting C<$TAP::Harness::Compatible::verbose> will override this,
or you can use the C<-v> switch in the F<prove> utility.

=item C<HARNESS_STRAP_CLASS>

Defines the TAP::Harness::Compatible::Straps subclass to use.  The value may either
be a filename or a class name.

If HARNESS_STRAP_CLASS is a class name, the class must be in C<@INC>
like any other class.

If HARNESS_STRAP_CLASS is a filename, the .pm file must return the name
of the class, instead of the canonical "1".

=back

=head1 EXAMPLE

Here's how TAP::Harness::Compatible tests itself

  $ cd ~/src/devel/Test-Harness
  $ perl -Mblib -e 'use TAP::Harness::Compatible qw(&runtests $verbose);
    $verbose=0; runtests @ARGV;' t/*.t
  Using /home/schwern/src/devel/Test-Harness/blib
  t/base..............ok
  t/nonumbers.........ok
  t/ok................ok
  t/test-harness......ok
  All tests successful.
  Files=4, Tests=24, 2 wallclock secs ( 0.61 cusr + 0.41 csys = 1.02 CPU)

=head1 SEE ALSO

The included F<prove> utility for running test scripts from the command line,
L<Test> and L<Test::Simple> for writing test scripts, L<Benchmark> for
the underlying timing routines, and L<Devel::Cover> for test coverage
analysis.

=head1 TODO

Provide a way of running tests quietly (ie. no printing) for automated
validation of tests.  This will probably take the form of a version
of runtests() which rather than printing its output returns raw data
on the state of the tests.  (Partially done in TAP::Harness::Compatible::Straps)

Document the format.

Fix HARNESS_COMPILE_TEST without breaking its core usage.

Figure a way to report test names in the failure summary.

Rework the test summary so long test names are not truncated as badly.
(Partially done with new skip test styles)

Add option for coverage analysis.

Trap STDERR.

Implement Straps total_results()

Remember exit code

Completely redo the print summary code.

Straps->analyze_file() not taint clean, don't know if it can be

Fix that damned VMS nit.

Add a test for verbose.

Change internal list of test results to a hash.

Fix stats display when there's an overrun.

Fix so perls with spaces in the filename work.

Keeping whittling away at _run_all_tests()

Clean up how the summary is printed.  Get rid of those damned formats.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-harness at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Harness>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the F<perldoc> command.

    perldoc TAP::Harness::Compatible

You can get docs for F<prove> with

    prove --man

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Harness>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Harness>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Harness>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Harness>

=back

=head1 SOURCE CODE

The source code repository for TAP::Harness::Compatible is at
L<http://svn.perl.org/modules/Test-Harness>.

=head1 AUTHORS

Either Tim Bunce or Andreas Koenig, we don't know. What we know for
sure is, that it was inspired by Larry Wall's F<TEST> script that came
with perl distributions for ages. Numerous anonymous contributors
exist.  Andreas Koenig held the torch for many years, and then
Michael G Schwern.

Current maintainer is Andy Lester C<< <andy at petdance.com> >>.

=head1 COPYRIGHT

Copyright 2002-2006
by Michael G Schwern C<< <schwern at pobox.com> >>,
Andy Lester C<< <andy at petdance.com> >>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>.

=head1 TO DOCUMENT

=over

=item bailout_handler

TODO: Document bailout_handler

=item get_results

Not documented in Test::Harness - so assume it's private.

=item header_handler

TODO: Document header_handler

=item strap

TODO: Document strap

=item strap_callback

TODO: Document strap_callback

=item swrite

TODO: Document swrite

=item test_handler

TODO: Document test_handler

=back
