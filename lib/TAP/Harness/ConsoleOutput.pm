package TAP::Harness::ConsoleOutput;

use strict;
use Benchmark;
use File::Spec;
use File::Path;

use TAP::Base;
use TAP::Parser;
use TAP::Harness;

# use TAP::Parser::Aggregator;

use vars qw($VERSION @ISA);

@ISA = qw(TAP::Base);

my $MAX_ERRORS = 5;
my %VALIDATION_FOR;
my $TIME_HIRES;

BEGIN {
    eval 'use Time::HiRes qw(time)';
    $TIME_HIRES = !$@;
}

BEGIN {
    %VALIDATION_FOR = (
        directives   => sub { shift; shift },
        verbose      => sub { shift; shift },
        timer        => sub { shift; shift },
        failures     => sub { shift; shift },
        errors       => sub { shift; shift },
        quiet        => sub { shift; shift },
        really_quiet => sub { shift; shift },
        stdout => sub {
            my ( $self, $ref ) = @_;
            $self->_croak("option 'stdout' needs a filehandle")
              unless ( ( ref($ref) || '' ) eq 'GLOB'
                or eval { $ref->can('print') } );
            return ($ref);
        },
    );

    my @getter_setters = qw(
      _longest _tests_without_extensions
      _newline_printed
      _current_test_name
      _plan
      _output_method
      _start_time
      _printed_summary_header
    );

    for my $method ( @getter_setters, keys %VALIDATION_FOR ) {
        no strict 'refs';
        if ( $method eq 'lib' || $method eq 'switches' ) {
            *$method = sub {
                my $self = shift;
                unless (@_) {
                    $self->{$method} ||= [];
                    return
                      wantarray ? @{ $self->{$method} } : $self->{$method};
                }
                $self->_croak("Too many arguments to method '$method'")
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

=head1 NAME

TAP::Harness::ConsoleOutput - Harness output delegate for default console output

=head1 VERSION

Version 2.99_03

=cut

$VERSION = '2.99_03';

=head1 DESCRIPTION

This is a simple test harness which allows tests to be run and results
automatically aggregated and output to STDOUT.

=head1 SYNOPSIS

 use TAP::Harness::ConsoleOutput;
 my $harness = TAP::Harness::ConsoleOutput->new( \%args );
 $harness->runtests(@tests);

=cut

sub _error {
    my $self = shift;
    return $self->{error} unless @_;
    $self->{error} = shift;
}

{

    sub _initialize {
        my ( $self, $arg_for ) = @_;
        $arg_for ||= {};

        $self->SUPER::_initialize($arg_for);
        my %arg_for = %$arg_for;    # force a shallow copy

        for my $name ( keys %VALIDATION_FOR ) {
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

sub prepare {
    my ( $self, @tests ) = @_;

    my $longest = 0;

    my $tests_without_extensions = 0;
    foreach my $test (@tests) {
        $longest = length $test if length $test > $longest;
        if ( $test !~ /\.\w+$/ ) {

            # TODO: Coverage?
            $tests_without_extensions = 1;
        }
    }

    $self->_tests_without_extensions($tests_without_extensions);
    $self->_longest($longest);
}

sub _format_name {
    my ( $self, $test ) = @_;
    my $name  = $test;
    my $extra = 0;
    unless ( $self->_tests_without_extensions ) {
        $name =~ s/(\.\w+)$//;    # strip the .t or .pm
        $extra = length $1;
    }
    my $periods = '.' x ( $self->_longest + $extra + 4 - length $test );
    return "$name$periods";
}

sub before_test {
    my ( $self, $test ) = @_;
    my $really_quiet = $self->really_quiet;
    $self->_current_test_name( $self->_format_name($test) );
    $self->_plan('');
    $self->_output_method('_output');
    $self->_start_time( time() );

    $self->_output( $self->_current_test_name ) unless $really_quiet;
    $self->_newline_printed(0);
}

sub after_test {
    my ( $self, $parser ) = @_;
    my $output       = $self->_output_method;
    my $really_quiet = $self->really_quiet;
    my $start_time   = $self->_start_time;
    my $show_count   = $self->_should_show_count;
    my $leader       = $self->_current_test_name;

    if ($show_count) {
        my $spaces
          = ' ' x ( 1 
              + length($leader) 
              + length( $self->_plan )
              + length( $parser->tests_run ) );
        $self->$output("\r$spaces\r$leader")
          unless $really_quiet;
    }

    unless ( $parser->has_problems ) {
        unless ($really_quiet) {
            my $time_report = '';
            if ( $self->timer ) {
                my $elapsed = time - $start_time;
                $time_report
                  = $TIME_HIRES
                  ? sprintf( ' %8d ms', $elapsed * 1000 )
                  : sprintf( ' %8s s', $elapsed || '<1' );
            }

            $self->_output("ok$time_report\n");
        }
    }
    else {
        $self->_output_test_failure($parser);
    }
}

sub result {
    my ( $self, $result, $prev_result, $parser ) = @_;

    my $show_count   = $self->_should_show_count;
    my $really_quiet = $self->really_quiet;
    my $planned      = $parser->tests_planned;

    if ( $result->is_bailout ) {
        $self->_failure_output( "Bailout called.  Further testing stopped:  "
              . $result->explanation
              . "\n" );
    }

    $self->_plan( '/' . ( $planned || 0 ) . ' ' ) unless $self->_plan;

    $self->_output_method( $self->_get_output_method_method($parser) );

    if ( $show_count and not $really_quiet and $result->is_test ) {
        my $number = $result->number;

        # $test_print_modulus *= 2 while $test_print_modulus < $number / 5;
        # unless ( $number % $test_print_modulus ) {
        my $output = $self->_output_method;
        $self->$output(
            "\r" . $self->_current_test_name . $number . $self->_plan );

        # }
    }

    return if $really_quiet;

    if ( $self->_should_display( $parser, $result, $prev_result ) ) {
        unless ( $self->_newline_printed ) {
            $self->_output("\n") unless $self->quiet;
            $self->_newline_printed(1);
        }

        # TODO: quiet gets tested here /and/ in _should_display
        unless ( $self->quiet ) {
            $self->_output_method_result( $parser, $result, $prev_result );
            $self->_output("\n");
        }
    }
}

sub summary {
    my ( $self, $arg_for ) = @_;
    my ( $start_time, $aggregate, $tests )
      = @$arg_for{qw( start aggregate tests )};

    my $end_time = $arg_for->{end} || Benchmark->new;

    my $runtime = timestr( timediff( $end_time, $start_time ), 'nop' );

    my $total  = $aggregate->total;
    my $passed = $aggregate->passed;

    # TODO: Check this condition still works when all subtests pass but
    # the exit status is nonzero

    if ( $total && $total == $passed && !$aggregate->has_problems ) {
        $self->_output("All tests successful.\n");
    }

    # ~TODO option where $aggregate->skipped generates reports
    if ( $total != $passed or $aggregate->has_problems ) {
        $self->_output("\nTest Summary Report");
        $self->_output("\n-------------------\n");
        foreach my $test (@$tests) {
            $self->_printed_summary_header(0);
            my ($parser) = $aggregate->parsers($test);
            $self->_output_method_summary_failure(
                'failed', "  Failed tests:  ",
                $test,    $parser
            );
            $self->_output_method_summary_failure(
                'todo_passed',
                "  TODO passed:   ", $test, $parser
            );

            # ~TODO this cannot be the default
            #$self->_output_method_summary_failure( 'skipped', "  Tests skipped: " );

            if ( my $exit = $parser->exit ) {
                $self->_summary_test_header( $test, $parser );
                $self->_failure_output("  Non-zero exit status: $exit\n");
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
                $self->_failure_output(
                    sprintf "  Parse errors: %s\n",
                    shift @errors
                );
                foreach my $error (@errors) {
                    my $spaces = ' ' x 16;
                    $self->_failure_output("$spaces$error\n");
                }
                $self->_failure_output($explain) if $explain;
            }
        }
    }
    my $files = @$tests;
    $self->_output("Files=$files, Tests=$total, $runtime\n");
    my $status = $aggregate->get_status;
    $self->_output("Result: $status\n");
}

sub _output_method_summary_failure {
    my ( $self, $method, $name, $test, $parser ) = @_;

    # ugly hack.  Must rethink this :(
    my $output = $method eq 'failed' ? '_failure_output' : 'output';

    # my $test   = $self->_curr_test;
    # my $parser = $self->_curr_parser;
    if ( $parser->$method() ) {
        $self->_summary_test_header( $test, $parser );
        $self->$output($name);
        my @results = $self->_balanced_range( 40, $parser->$method() );
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
    my $output = $self->_get_output_method_method($parser);
    $self->$output(
        sprintf "$test$spaces(Wstat: %d Tests: %d Failed: %d)\n",
        $parser->wait, $parser->tests_run, scalar $parser->failed
    );
    $self->_printed_summary_header(1);
}

sub _output {
    my $self = shift;

    print { $self->stdout } @_;
}

sub _failure_output {
    shift->_output(@_);
}

sub _balanced_range {
    my ( $self, $limit, @range ) = @_;
    @range = $self->_range(@range);
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

sub _range {
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

sub _output_test_failure {
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
        $self->_failure_output(" Dubious, test returned $status\n");
    }

    if ( $failed == 0 ) {
        $self->_failure_output(
            $total ? " All $total subtests passed " : " No subtests run " );
    }
    else {
        $self->_failure_output(" Failed $failed/$total subtests ");
        if ( !$total ) {
            $self->_failure_output("\nNo tests run!");
        }
    }

    if ( my $skipped = $parser->skipped ) {
        $passed -= $skipped;
        my $test = 'subtest' . ( $skipped != 1 ? 's' : '' );
        $self->_output("\n\t(less $skipped skipped $test: $passed okay)");
    }

    if ( my $failed = $parser->todo_passed ) {
        my $test = $failed > 1 ? 'tests' : 'test';
        $self->_output("\n\t($failed TODO $test unexpectedly succeeded)");
    }

    $self->_output("\n");
}

sub _format_result {
    my ( $self, $result, $prev_result ) = @_;
    return $result->as_string;
}

sub _output_method_result {
    my ( $self, $parser, $result, $prev_result ) = @_;
    $self->_output( $self->_format_result( $result, $prev_result ) );
}

sub _get_output_method_method {
    my ( $self, $parser ) = @_;
    return $parser->has_problems ? '_failure_output' : '_output';
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

1;

__END__

=over

=item C<output>

=item C<after_test>

=item C<before_test>

=item C<directives>

=item C<errors>

=item C<failures>

=item C<prepare>

=item C<quiet>

=item C<really_quiet>

=item C<result>

=item C<stdout>

=item C<summary>

=item C<timer>

=item C<verbose>

=back
