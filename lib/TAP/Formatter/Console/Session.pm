package TAP::Formatter::Console::Session;

use strict;
use Benchmark;
use File::Spec;
use File::Path;

use TAP::Base;
use Carp;

use vars qw($VERSION @ISA);

@ISA = qw(TAP::Base);

my %VALIDATION_FOR;

BEGIN {
    %VALIDATION_FOR = (
        name      => sub { shift; shift },
        formatter => sub { shift; shift },
        parser    => sub { shift; shift },
    );

    my @getter_setters = qw(
      _prev_result
      _plan
      _output_method
      _newline_printed
    );

    # TODO: We don't really need all this do we?
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

TAP::Formatter::Console::Session - Harness output delegate for default console output

=head1 VERSION

Version 2.99_03

=cut

$VERSION = '2.99_03';

=head1 DESCRIPTION

This provides console orientated output formatting for TAP::Harness.

=head1 SYNOPSIS

=cut

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my %args = (
    formatter => $self,
 )
 my $harness = TAP::Formatter::Console->new( \%args );

The constructor returns a new C<TAP::Formatter::Console> object. The following options are allowed:

=over 4

=item * C<formatter>

=item * C<parser>

=item * C<name>

=back

=cut

sub _initialize {
    my ( $self, $arg_for ) = @_;
    $arg_for ||= {};

    $self->SUPER::_initialize($arg_for);
    my %arg_for = %$arg_for;    # force a shallow copy

    for my $name ( keys %VALIDATION_FOR ) {
        my $property = delete $arg_for{$name};
        if ( defined $property ) {
            my $validate = $VALIDATION_FOR{$name};
            $self->$name( $self->$validate($property) );
        }
    }

    if ( my @props = keys %arg_for ) {
        $self->_croak("Unknown arguments to TAP::Harness::new (@props)");
    }

    $self->_plan('');
    $self->_output_method('_output');
    my $formatter = $self->formatter;

    $formatter->_output( $self->name )
      unless $formatter->really_quiet;

    $self->_newline_printed(0);

    return $self;
}

=head3 C<result>

Called by the harness for each line of TAP it receives.

=cut

sub result {
    my ( $self, $result ) = @_;

    my $parser      = $self->parser;
    my $formatter   = $self->formatter;
    my $prev_result = $self->_prev_result;

    $self->_prev_result($result);

    my $really_quiet = $formatter->really_quiet;
    my $show_count   = $self->_should_show_count;
    my $planned      = $parser->tests_planned;

    if ( $result->is_bailout ) {
        $formatter->_failure_output(
                "Bailout called.  Further testing stopped:  "
              . $result->explanation
              . "\n" );
    }

    $self->_plan( '/' . ( $planned || 0 ) . ' ' ) unless $self->_plan;

    $self->_output_method( $formatter->_get_output_method($parser) );

    if ( $show_count and not $really_quiet and $result->is_test ) {
        my $number = $result->number;

        my $test_print_modulus = 1;
        my $ceiling            = $number / 5;
        $test_print_modulus *= 2 while $test_print_modulus < $ceiling;

        unless ( $number % $test_print_modulus ) {
            my $output = $self->_output_method;
            $formatter->$output(
                "\r" . $self->name . $number . $self->_plan );
        }
    }

    return if $really_quiet;

    if ( $self->_should_display($result) ) {
        unless ( $self->_newline_printed ) {
            $formatter->_output("\n") unless $formatter->quiet;
            $self->_newline_printed(1);
        }

        # TODO: quiet gets tested here /and/ in _should_display
        unless ( $formatter->quiet ) {
            $self->_output_result($result);
            $formatter->_output("\n");
        }
    }
}

=head3 C<close_test>

Called to close a test session.

=cut

sub close_test {
    my $self = shift;

    my $parser       = $self->parser;
    my $formatter    = $self->formatter;
    my $output       = $self->_output_method;
    my $really_quiet = $formatter->really_quiet;
    my $show_count   = $self->_should_show_count;
    my $leader       = $self->name;

    if ( $show_count && !$really_quiet ) {
        my $spaces
          = ' ' x length( '.' . $leader . $self->_plan . $parser->tests_run );
        $formatter->$output("\r$spaces\r$leader");
    }

    unless ( $parser->has_problems ) {
        unless ($really_quiet) {
            my $time_report = '';
            if ( $formatter->timer ) {
                my $start_time = $parser->start_time;
                my $end_time   = $parser->end_time;
                if ( defined $start_time and defined $end_time ) {
                    my $elapsed = $end_time - $start_time;
                    $time_report
                      = $self->time_is_hires
                      ? sprintf( ' %5.3f s', $elapsed )
                      : sprintf( ' %8s s', $elapsed || '<1' );
                }
            }

            $formatter->_output("ok$time_report\n");
        }
    }
    else {
        $formatter->_output_test_failure($parser);
    }
}

sub _should_display {
    my ( $self, $result ) = @_;

    my $formatter = $self->formatter;
    my $parser    = $self->parser;

    # Always output directives
    return $result->has_directive if $formatter->directives;

    # Nothing else if really quiet
    return 0 if $formatter->really_quiet;

    return 1
      if $self->_should_show_failure($result)
          || ( $formatter->verbose && !$formatter->failures );

    return 0;
}

sub _should_show_failure {
    my ( $self, $result ) = @_;

    return if !$result->is_test;
    return $self->formatter->failures && !$result->is_ok;
}

sub _should_show_count {

    # we need this because if someone tries to redirect the output, it can get
    # very garbled from the carriage returns (\r) in the count line.
    return !shift->formatter->verbose && -t STDOUT;
}

{
    my @COLOR_MAP = (
        {   test => sub { $_->is_test && !$_->is_ok },
            colors => ['red'],
        },
        {   test => sub { $_->is_test && $_->has_skip },
            colors => [
                'white',
                'on_blue'
            ],
        },
        {   test => sub { $_->is_test && $_->has_todo },
            colors => ['white'],
        },
    );

    sub _output_result {
        my ( $self, $result ) = @_;
        my $formatter   = $self->formatter;
        my $parser      = $self->parser;
        my $prev_result = $self->_prev_result;
        if ( $formatter->_colorizer ) {
            for my $col (@COLOR_MAP) {
                local $_ = $result;
                if ( $col->{test}->() ) {
                    $formatter->_set_colors( @{ $col->{colors} } );
                    last;
                }
            }
        }
        $formatter->_output( $result->as_string );
        $formatter->_set_colors('reset');
    }
}

1;
