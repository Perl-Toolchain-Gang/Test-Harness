package TAP::Harness;

use strict;
use Benchmark;
use File::Spec;
use File::Path;

use TAP::Base;
use TAP::Parser;
use TAP::Parser::Aggregator;

use vars qw($VERSION @ISA);

@ISA = qw(TAP::Base);

=head1 NAME

TAP::Harness - Run Perl test scripts with statistics

=head1 VERSION

Version 2.99_01

=cut

$VERSION = '2.99_01';

$ENV{HARNESS_ACTIVE}  = 1;
$ENV{HARNESS_VERSION} = $VERSION;

END {

    # For VMS.
    delete $ENV{HARNESS_ACTIVE};
    delete $ENV{HARNESS_VERSION};
}

my $TIME_HIRES;
my $MAX_ERRORS = 5;

BEGIN {
    eval 'use Time::HiRes qw(time)';
    $TIME_HIRES = !$@;

}

=head1 DESCRIPTION

This is a simple test harness which allows tests to be run and results
automatically aggregated and output to STDOUT.

=head1 SYNOPSIS

 use TAP::Harness;
 my $harness = TAP::Harness->new( \%args );
 $harness->runtests(@tests);

=cut

my %VALIDATION_FOR;

sub _error {
    my $self = shift;
    return $self->{error} unless @_;
    $self->{error} = shift;
}

BEGIN {
    %VALIDATION_FOR = (
        lib => sub {
            my ( $self, $libs ) = @_;
            $libs = [$libs] unless 'ARRAY' eq ref $libs;
            my @bad_libs;
            foreach my $lib (@$libs) {
                unless ( -d $lib ) {
                    push @bad_libs, $lib;
                }
            }
            if (@bad_libs) {
                my $dirs = 'lib';
                $dirs .= 's' if @bad_libs > 1;
                $self->_error("No such $dirs (@bad_libs)");
            }
            return [ map { '-I' . File::Spec->rel2abs($_) } @$libs ];
        },
        switches => sub {
            my ( $self, $switches ) = @_;
            $switches = [$switches] unless 'ARRAY' eq ref $switches;
            my @switches = map { /^-/ ? $_ : "-$_" } @$switches;
            my %found = map { $_ => 0 } @switches;
            @switches = grep { !$found{$_}++ } @switches;
            return \@switches;
        },
        directives   => sub { shift; shift },
        verbose      => sub { shift; shift },
        timer        => sub { shift; shift },
        failures     => sub { shift; shift },
        errors       => sub { shift; shift },
        quiet        => sub { shift; shift },
        really_quiet => sub { shift; shift },
        exec         => sub { shift; shift },
        merge        => sub { shift; shift },
        formatter    => sub { shift; shift },
        stdout => sub {
            my ( $self, $ref ) = @_;
            $self->_croak("option 'stdout' needs a filehandle")
              unless ( ( ref($ref) || '' ) eq 'GLOB'
                or eval { $ref->can('print') } );
            return ($ref);
        },
    );
    my @getter_setters = qw/
      _curr_parser
      _curr_test
      _longest
      _newline_printed
      _printed_summary_header
      /;

    foreach my $method ( @getter_setters, keys %VALIDATION_FOR ) {
        no strict 'refs';
        if ( $method eq 'lib' || $method eq 'switches' ) {
            *$method = sub {
                my $self = shift;
                unless (@_) {
                    $self->{$method} ||= [];
                    return
                      wantarray ? @{ $self->{$method} } : $self->{$method};
                }
                $self->_croak("Too many arguments to &\$method")
                  if @_ > 1;
                my $args = shift;
                $args = [$args] unless ref $args;
                $self->{$method} = $args;
                return $self;
            };
        }
        else {
            *$method = sub {
                my $self = shift;
                return $self->{$method} unless @_;
                $self->{$method} = shift;
            };
        }
    }
}

##############################################################################

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my %args = (
    verbose => 1,
    lib     => [ 'lib', 'blib/lib' ],
 )
 my $harness = TAP::Harness->new( \%args );

The constructor returns a new C<TAP::Harness> object.  It accepts an optional
hashref whose allowed keys are:

=over 4

=item * C<verbose>

Print individual test results to STDOUT.

=item * C<timer>

Append run time for each test to output. Uses L<Time::HiRes> if available.

=item * C<failures>

Only show test failures (this is a no-op if C<verbose> is selected).

=item * C<lib>

Accepts a scalar value or array ref of scalar values indicating which paths to
allowed libraries should be included if Perl tests are executed.  Naturally,
this only makes sense in the context of tests written in Perl.

=item * C<switches>

Accepts a scalar value or array ref of scalar values indicating which switches
should be included if Perl tests are executed.  Naturally, this only makes
sense in the context of tests written in Perl.

=item * C<quiet>

Suppress some test output (mostly failures while tests are running).

=item * C<really_quiet>

Suppress everything but the tests summary.

=item * C<exec>

Typically, Perl tests are run through this.  However, anything which spits out
TAP is fine.  You can use this argument to specify the name of the program
(and optional switches) to run your tests with:

  exec => '/usr/bin/ruby -w'
  
=item * C<merge>

If C<merge> is true the harness will create parsers that merge STDOUT
and STDERR together for any processes they start.

=item * C<formatter>

If set C<formatter> must be an object that is capable of formatting
individual items from the TAP stream. For each type of item it is
capable of formatting it must expose a method called format_I<type>.

For example:

    sub format_yaml {
        my ($self, $harness, $result, $prev_result) = @_;
        # Format the item and return a string
        return _format_yaml_line( $result, $prev_result );
    }

The formatting method is called with three arguments in addition to $self:

=over

=item C<$harness>

The test harness.

=item C<$result>

The result which we should format.

=item C<$prev_result>

The previous result. This is necessary in the case of, for example,
C<format_yaml> which will want to know whether the preceding test passed
or failed.

=back

=item * C<errors>

If parse errors are found in the TAP output, a note of this will be made
in the summary report.  To see all of the parse errors, set this argument to
true:

  errors => 1

=item * C<directives>

If set to a true value, only test results with directives will be displayed.
This overrides other settings such as C<verbose> or C<failures>.

=item * C<stdout>

A filehandle for catching standard output.

=back

=cut

# new supplied by TAP::Base

{
    my @legal_callback = qw(
      made_parser
    );

    sub _initialize {
        my ( $self, $arg_for ) = @_;
        $arg_for ||= {};

        $self->SUPER::_initialize( $arg_for, \@legal_callback );
        my %arg_for = %$arg_for;    # force a shallow copy

        foreach my $name ( keys %VALIDATION_FOR ) {
            my $property = delete $arg_for{$name};
            if ( defined $property ) {
                my $validate = $VALIDATION_FOR{$name};

                my $value = $self->$validate($property);
                if ( $self->_error ) {
                    $self->_croak;
                }
                $self->$name($value);
            }
        }
        if ( my @props = keys %arg_for ) {
            $self->_croak("Unknown arguments to TAP::Harness::new (@props)");
        }
        $self->quiet(0) unless $self->quiet;    # suppress unit warnings
        $self->really_quiet(0)    unless $self->really_quiet;
        $self->stdout( \*STDOUT ) unless $self->stdout;
        return $self;
    }
}

##############################################################################

=head2 Instance Methods

=head3 C<runtests>

  $harness->runtests(@tests);

Accepts and array of C<@tests> to be run.  This should generally be the names
of test files, but this is not required.  Each element in C<@tests> will be
passed to C<TAP::Parser::new()> as a C<source>.  See L<TAP::Parser> for more
information.

Tests will be run in the order found.

If the environment variable C<PERL_TEST_HARNESS_DUMP_TAP> is defined it
should name a directory into which a copy of the raw TAP for each test
will be written. TAP is written to files named for each test.
Subdirectories will be created as needed.

Returns a L<TAP::Parser::Aggregator> containing the test results.

=cut

sub runtests {
    my ( $self, @tests ) = @_;

    my $aggregate = TAP::Parser::Aggregator->new;

    my $results = $self->aggregate_tests( $aggregate, @tests );

    $self->summary($results);

    # XXX where to put the exit status?
    # die "something failed" if($aggregate->has_problems);

    return $aggregate;
}

=head3 C<aggregate_tests>

  $harness->aggregate_tests( $aggregate, @tests );

Tests will be run in the order found.

=cut

sub aggregate_tests {
    my ( $self, $aggregate, @tests ) = @_;

    my $longest = 0;

    my $tests_without_extensions = 0;
    foreach my $test (@tests) {
        $longest = length $test if length $test > $longest;
        if ( $test !~ /\.\w+$/ ) {
            $tests_without_extensions = 1;
        }
    }
    $self->_longest($longest);

    my $start_time = Benchmark->new;

    foreach my $test (@tests) {
        my $extra = 0;
        my $name  = $test;
        unless ($tests_without_extensions) {
            if ( $name =~ s/(\.\w+)$// ) {    # strip the .t or .pm
                $extra = length $1;
            }
        }
        my $periods = '.' x ( $longest + $extra + 4 - length $test );

        my $parser = $self->_runtest( "$name$periods", $test );
        $aggregate->add( $test, $parser );
    }

    return {
        start     => $start_time,
        end       => Benchmark->new,
        aggregate => $aggregate,
        tests     => \@tests
    };
}

##############################################################################

=head1 SUBCLASSING

C<TAP::Harness> is designed to be (mostly) easy to subclass.  If you don't
like how a particular feature functions, just override the desired methods.

=head2 Methods

The following methods are one's you may wish to override if you want to
subclass C<TAP::Harness>.

=head3 C<summary>

  $harness->summary( \%args );

C<summary> prints the summary report after all tests are run.  The argument is
a hashref with the following keys:

=over 4

=item * C<start>

This is created with C<< Benchmark->new >> and it the time the tests started.
You can print a useful summary time, if desired, with:

  $self->output(timestr( timediff( Benchmark->new, $start_time ), 'nop' ));

=item * C<tests>

This is an array reference of all test names.  To get the L<TAP::Parser>
object for individual tests:

 my $aggregate = $args->{aggregate};
 my $tests     = $args->{tests};

 foreach my $name ( @$tests ) {
     my ($parser) = $aggregate->parsers($test);
     ... do something with $parser
 }

This is a bit clunky and will be cleaned up in a later release.

=back

=cut

sub summary {
    my ( $self, $arg_for ) = @_;
    my ( $start_time, $aggregate, $tests )
      = @$arg_for{qw< start aggregate tests >};

    my $end_time = $arg_for->{end} || Benchmark->new;

    my $runtime = timestr( timediff( $end_time, $start_time ), 'nop' );

    my $total  = $aggregate->total;
    my $passed = $aggregate->passed;

    # TODO: Check this condition still works when all subtests pass but
    # the exit status is nonzero

    if ( $total && $total == $passed && !$aggregate->has_problems ) {
        $self->output("All tests successful.\n");
    }
    if (   $total != $passed
        or $aggregate->has_problems
        or $aggregate->skipped )
    {
        $self->output("\nTest Summary Report");
        $self->output("\n-------------------\n");
        foreach my $test (@$tests) {
            $self->_printed_summary_header(0);
            my ($parser) = $aggregate->parsers($test);
            $self->_curr_test($test);
            $self->_curr_parser($parser);
            $self->_output_summary_failure( 'failed', "  Failed tests:  " );
            $self->_output_summary_failure(
                'todo_passed',
                "  TODO passed:   "
            );
            $self->_output_summary_failure( 'skipped', "  Tests skipped: " );

            if ( my $exit = $parser->exit ) {
                $self->_summary_test_header( $test, $parser );
                $self->failure_output("  Non-zero exit status: $exit\n");
            }

            if ( my @errors = $parser->parse_errors ) {
                my $explain;
                if ( @errors > $MAX_ERRORS && !$self->errors ) {
                    $explain
                      = "Displayed the first $MAX_ERRORS of "
                      . scalar(@errors)
                      . " TAP syntax errors.\n"
                      . "Re-run prove with the -p option to see them all.\n";
                    splice @errors, $MAX_ERRORS;
                }
                $self->_summary_test_header( $test, $parser );
                $self->failure_output(
                    sprintf "  Parse errors: %s\n",
                    shift @errors
                );
                foreach my $error (@errors) {
                    my $spaces = ' ' x 16;
                    $self->failure_output("$spaces$error\n");
                }
                $self->failure_output($explain) if $explain;
            }
        }
    }
    my $files = @$tests;
    $self->output("Files=$files, Tests=$total, $runtime\n");
}

sub _output_summary_failure {
    my ( $self, $method, $name ) = @_;

    # ugly hack.  Must rethink this :(
    my $output = $method eq 'failed' ? 'failure_output' : 'output';
    my $test   = $self->_curr_test;
    my $parser = $self->_curr_parser;
    if ( $parser->$method() ) {
        $self->_summary_test_header( $test, $parser );
        $self->$output($name);
        my @results = $self->balanced_range( 40, $parser->$method() );
        $self->$output( sprintf "%s\n" => shift @results );
        my $spaces = ' ' x 16;
        while (@results) {
            $self->$output( sprintf "$spaces%s\n" => shift @results );
        }
    }
}

sub _summary_test_header {
    my ( $self, $test, $parser ) = @_;
    return if $self->_printed_summary_header;
    my $spaces = ' ' x ( $self->_longest - length $test );
    $spaces = ' ' unless $spaces;
    my $output = $self->_get_output_method($parser);
    $self->$output(
        sprintf "$test$spaces(Wstat: %d Tests: %d Failed: %d)\n",
        $parser->wait, $parser->tests_run, scalar $parser->failed
    );
    $self->_printed_summary_header(1);
}

##############################################################################

=head3 C<output>

  $harness->output(@list_of_strings_to_output);

All output from C<TAP::Harness> is driven through this method.  If you would
like to redirect output somewhere else, just override this method.

=cut

sub output {
    my $self = shift;

    print {$self->stdout} @_;
}

##############################################################################

=head3 C<failure_output>

  $harness->failure_output(@list_of_strings_to_output);

Identical to C<output>, this method is called for any output which represents
a failure.

=cut

sub failure_output {
    shift->output(@_);
}

##############################################################################

=head3 C<balanced_range>

 my @ranges = $harness->balanced_range( $limit, @numbers );

Given a limit in the number of characters and a list of numbers, this method
first creates a range of numbers with C<range> and then groups them into
individual strings which are roughly the length of C<$limit>.  Returns an
array of strings.

=cut

sub balanced_range {
    my ( $self, $limit, @range ) = @_;
    @range = $self->range(@range);
    my $line = "";
    my @lines;
    my $curr = 0;
    while (@range) {
        if ( $curr < $limit ) {
            my $range = ( shift @range ) . ", ";
            $line .= $range;
            $curr += length $range;
        }
        elsif (@range) {
            $line =~ s/, $//;
            push @lines => $line;
            $line = '';
            $curr = 0;
        }
    }
    if ($line) {
        $line =~ s/, $//;
        push @lines => $line;
    }
    return @lines;
}

##############################################################################

=head3 C<range>

 my @range = $harness->range(@list_of_numbers);

Taks a list of numbers, sorts them, and returns a list of ranged strings:

 print join ', ' $harness->range( 2, 7, 1, 3, 10, 9  );
 # 1-3, 7, 9-10

=cut

sub range {
    my ( $self, @numbers ) = @_;

    # shouldn't be needed, but subclasses might call this
    @numbers = sort { $a <=> $b } @numbers;
    my ( $min, @range );

    foreach my $i ( 0 .. $#numbers ) {
        my $num  = $numbers[$i];
        my $next = $numbers[ $i + 1 ];
        if ( defined $next && $next == $num + 1 ) {
            if ( !defined $min ) {
                $min = $num;
            }
        }
        elsif ( defined $min ) {
            push @range => "$min-$num";
            undef $min;
        }
        else {
            push @range => $num;
        }
    }
    return @range;
}

##############################################################################

=head3 C<output_test_failure>

  $harness->output_test_failure($parser);

As individual test programs are run, if a test program fails, this method is
called to spit out the list of failed tests.

=cut

sub output_test_failure {
    my ( $self, $parser ) = @_;
    return if $self->really_quiet;

    my $tests_run     = $parser->tests_run;
    my $tests_planned = $parser->tests_planned;

    my $total
      = defined $tests_planned
      ? $tests_planned
      : $tests_run;

    my $passed = $parser->passed;

    # The total number of fails includes any tests that were planned but
    # didn't run
    my $failed = $parser->failed + $total - $tests_run;
    my $exit   = $parser->exit;

    # TODO: $flist isn't used anywhere
    # my $flist  = join ", " => $self->range( $parser->failed );

    if ( my $exit = $parser->exit ) {
        my $wstat = $parser->wait;
        my $status = sprintf( "%d (wstat %d, 0x%x)", $exit, $wstat, $wstat );
        $self->failure_output(" Dubious, test returned $status\n");
    }

    if ( $failed == 0 ) {
        $self->failure_output(" All $total subtests passed ");
    }
    else {
        $self->failure_output(" Failed $failed/$total subtests ");
        if ( !$total ) {
            $self->failure_output("\nNo tests run!");
        }
    }

    if ( my $skipped = $parser->skipped ) {
        $passed -= $skipped;
        my $test = 'subtest' . ( $skipped != 1 ? 's' : '' );
        $self->output("\n\t(less $skipped skipped $test: $passed okay)");
    }

    if ( my $failed = $parser->todo_passed ) {
        my $test = $failed > 1 ? 'tests' : 'test';
        $self->output("\n\t($failed TODO $test unexpectedly succeeded)");
    }

    $self->output("\n");
}

sub _get_parser_args {
    my ( $self, $test ) = @_;
    my %args = ();
    my @switches = $self->lib if $self->lib;
    push @switches => $self->switches if $self->switches;
    $args{switches} = \@switches;
    $args{spool}    = $self->_open_spool($test);
    $args{merge}    = $self->merge;
    $args{exec}     = $self->exec;
    if ( my $exec = $self->exec ) {
        $args{exec} = [ @$exec, $test ];
    }
    else {
        $args{source} = $test;
    }
    return \%args;
}

sub _runtest {
    my ( $self, $leader, $test ) = @_;

    my $really_quiet = $self->really_quiet;
    my $show_count   = $self->_should_show_count;
    $self->output($leader) unless $really_quiet;

    my $parser = TAP::Parser->new( $self->_get_parser_args($test) );

    $self->_make_callback( 'made_parser', $parser );

    my $plan = '';

    $self->_newline_printed(0);

    my $start_time  = time();
    my $output      = 'output';
    my $prev_result = undef;

    my $test_print_modulus = 1;
    while ( defined( my $result = $parser->next ) ) {
        my $planned = $parser->tests_planned;
        $output = $self->_get_output_method($parser);
        if ( $result->is_bailout ) {
            $self->failure_output(
                    "Bailout called.  Further testing stopped:  "
                  . $result->explanation
                  . "\n" );
            exit 1;
        }
        unless ($plan) {
            $plan = '/' . ( $planned || 0 ) . ' ';
        }
        if ( $show_count && !$really_quiet && $result->is_test ) {
            my $number = $result->number;
            $test_print_modulus *= 2 while $test_print_modulus < $number / 5;
            if ( !( $number % $test_print_modulus ) ) {
                $self->$output( "\r$leader" . $number . $plan );
            }
        }
        $self->_process( $parser, $result, $prev_result );
        $prev_result = $result;
    }

    $self->_close_spool;

    if ($show_count) {
        my $spaces
          = ' ' x ( 1 
              + length($leader) 
              + length($plan)
              + length( $parser->tests_run ) );
        $self->$output("\r$spaces\r$leader") unless $really_quiet;
    }
    if ( !$parser->has_problems ) {
        unless ($really_quiet) {
            my $time_report = '';
            if ( $self->timer ) {
                my $elapsed = time - $start_time;
                $time_report
                  = $TIME_HIRES
                  ? sprintf( ' %8d ms', $elapsed * 1000 )
                  : sprintf( ' %8s s', $elapsed || '<1' );
            }

            $self->output("ok$time_report\n");
        }
    }
    else {
        $self->output_test_failure($parser);
    }
    return $parser;
}

sub _open_spool {
    my $self = shift;
    my $test = shift;

    if ( my $spool_dir = $ENV{PERL_TEST_HARNESS_DUMP_TAP} ) {
        my $spool = File::Spec->catfile( $spool_dir, $test );

        # Make the directory
        my ( $vol, $dir, undef ) = File::Spec->splitpath($spool);
        my $path = File::Spec->catpath( $vol, $dir, '' );
        eval { mkpath($path) };
        $self->_croak($@) if $@;

        open( my $spool_handle, ">$spool" )
          or $self->_croak(" Can't write $spool ( $! ) ");
        return $self->{spool} = $spool_handle;
    }

    return;
}

sub _close_spool {
    my $self = shift;

    if ( my $spool_handle = delete $self->{spool} ) {
        close($spool_handle)
          or $self->_croak(" Error closing TAP spool file( $! ) \n ");
    }
}

sub _format_result {
    my ( $self, $result, $prev_result ) = @_;
    my $sig = 'format_' . $result->type;
    if ( my $formatter = $self->formatter ) {
        if ( my $method = $formatter->can($sig) ) {
            return $formatter->$method( $self, $result, $prev_result );
        }
    }
    return $result->as_string;
}

sub _output_result {
    my ( $self, $parser, $result, $prev_result ) = @_;
    $self->output( $self->_format_result( $result, $prev_result ) );
}

sub _process {
    my ( $self, $parser, $result, $prev_result ) = @_;
    return if $self->really_quiet;
    if ( $self->_should_display( $parser, $result, $prev_result ) ) {
        unless ( $self->_newline_printed ) {
            $self->output("\n") unless $self->quiet;
            $self->_newline_printed(1);
        }

        # TODO: quiet gets tested here /and/ in _should_display
        unless ( $self->quiet ) {
            $self->_output_result( $parser, $result, $prev_result );
            $self->output("\n");
        }
    }
}

sub _get_output_method {
    my ( $self, $parser ) = @_;
    return $parser->has_problems ? 'failure_output' : 'output';
}

sub _should_display {
    my ( $self, $parser, $result, $prev_result ) = @_;

    # Always output directives
    return $result->has_directive if $self->directives;

    # Nothing else if really quiet
    return 0 if $self->really_quiet;

    return 1
      if $self->_should_show_failure($result)
          || ( $self->verbose && !$self->failures );

    return 0;
}

sub _should_show_count {

    # we need this because if someone tries to redirect the output, it can get
    # very garbled from the carriage returns (\r) in the count line.
    return !shift->verbose && -t STDOUT;
}

sub _should_show_failure {
    my ( $self, $result ) = @_;

    return if !$result->is_test;
    return $self->failures && !$result->is_ok;
}

sub _croak {
    my ( $self, $message ) = @_;
    unless ($message) {
        $message = $self->_error;
    }
    $self->SUPER::_croak($message);
}

=head1 REPLACING

If you like the C<prove> utility and L<TAP::Parser> but you want your
own harness, all you need to do is write one and provide C<new> and
C<runtests> methods. Then you can use the C<prove> utility like so:

 prove --harness My::Test::Harness

Note that while C<prove> accepts a list of tests (or things to be
tested), C<new> has a fairly rich set of arguments. You'll probably want
to read over this code carefully to see how all of them are being used.

=head1 SEE ALSO

L<Test::Harness>

=cut

1;
