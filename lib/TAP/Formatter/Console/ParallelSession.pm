package TAP::Formatter::Console::ParallelSession;

use strict;
use File::Spec;
use File::Path;
use TAP::Formatter::Console::Session;
use Carp;

use constant WIDTH => 72;    # Because Eric says
use vars qw($VERSION @ISA);

@ISA = qw(TAP::Formatter::Console::Session);

my %shared;

sub _initialize {
    my ( $self, $arg_for ) = @_;

    $self->SUPER::_initialize($arg_for);
    my $formatter = $self->formatter;

    # Horrid bodge. This creates our shared context per harness. Maybe
    # TAP::Harness should give us this?
    my $context = $shared{$formatter} ||= $self->_create_shared_context;
    push @{ $context->{active} }, $self;

    return $self;
}

sub _create_shared_context {
    my $self = shift;
    return {
        active => [],
        tests  => 0,
        fails  => 0,
    };
}

sub _need_refresh {
    my $self      = shift;
    my $formatter = $self->formatter;
    $shared{$formatter}->{need_refresh}++;
}

=head1 NAME

TAP::Formatter::Console::ParallelSession - Harness output delegate for parallel console output

=head1 VERSION

Version 2.99_04

=cut

$VERSION = '2.99_04';

=head1 DESCRIPTION

This provides console orientated output formatting for L<TAP::Harness::Parallel>.

=head1 SYNOPSIS

=cut

=head1 METHODS

=head2 Class Methods

=head3 C<header>

Output test preamble

=cut

sub header {
    my $self = shift;

    # my $formatter = $self->formatter;
    #
    # $formatter->_output( $self->_pretty_name )
    #   unless $formatter->really_quiet;
    #
    # $self->_newline_printed(0);

    # $self->formatter->_output( "Starting ", $self->name, "\n" );
    $self->_need_refresh;
}

sub _refresh {

    # my $self      = shift;
    # my $formatter = $self->formatter;
    # my $context   = $shared{$formatter};
    # if ( delete $context->{need_refresh} ) {
    #     $self->_clear_line;
    #     for my $test ( @{ $context->{active} } ) {
    #         $formatter->_output( $test->_pretty_name, "\n" );
    #     }
    #     $formatter->_output("\n");
    # }
}

sub _clear_line {
    my $self = shift;
    $self->formatter->_output( "\r" . ( ' ' x WIDTH ) . "\r" );
}

sub _output_ruler {
    my $self      = shift;
    my $formatter = $self->formatter;
    return if $formatter->really_quiet;

    my $context = $shared{$formatter};

    # Too much boilerplate!
    my $ruler = sprintf( "===( %7d )", $context->{tests} );
    $ruler .= ( '=' x ( WIDTH - length $ruler ) );
    $formatter->_output("\r$ruler");
}

=head3 C<result>

  Called by the harness for each line of TAP it receives .

=cut

sub result {
    my ( $self, $result ) = @_;
    my $parser    = $self->parser;
    my $formatter = $self->formatter;
    my $context   = $shared{$formatter};

    $self->_refresh;

    # my $really_quiet = $formatter->really_quiet;
    # my $show_count   = $self->_should_show_count;
    my $planned = $parser->tests_planned;

    if ( $result->is_bailout ) {
        $formatter->_failure_output(
                "Bailout called.  Further testing stopped:  "
              . $result->explanation
              . "\n" );
    }

    # $self->_plan( '/' . ( $planned || 0 ) . ' ' ) unless $self->_plan;

    # $self->_output_method( my $output
    #       = $formatter->_get_output_method($parser) );

    if ( $result->is_test ) {
        $context->{tests}++;

        my $test_print_modulus = 1;
        my $ceiling            = $context->{tests} / 5;
        $test_print_modulus *= 2 while $test_print_modulus < $ceiling;

        unless ( $context->{tests} % $test_print_modulus ) {
            $self->_output_ruler;
        }
    }

    # if ( $show_count and not $really_quiet and $result->is_test ) {
    #     my $number = $result->number;
    #
    #     my $test_print_modulus = 1;
    #     my $ceiling            = $number / 5;
    #     $test_print_modulus *= 2 while $test_print_modulus < $ceiling;
    #
    #     unless ( $number % $test_print_modulus ) {
    #         my $output = $self->_output_method;
    #         $formatter->$output(
    #             "\r" . $self->_pretty_name . $number . $self->_plan );
    #     }
    # }
    #
    # return if $really_quiet;
    #
    # if ( $self->_should_display($result) ) {
    #     unless ( $self->_newline_printed ) {
    #         $formatter->_output("\n") unless $formatter->quiet;
    #         $self->_newline_printed(1);
    #     }
    #
    #     # TODO: quiet gets tested here /and/ in _should_display
    #     unless ( $formatter->quiet ) {
    #         $self->_output_result($result);
    #         $formatter->_output("\n");
    #     }
    # }

    # print ".";
}

=head3 C<close_test>

=cut

sub close_test {
    my $self      = shift;
    my $name      = $self->name;
    my $parser    = $self->parser;
    my $formatter = $self->formatter;
    my $context   = $shared{$formatter};

    unless ( $formatter->really_quiet ) {
        $self->_clear_line;

        # my $output = $self->_output_method;
        $formatter->_output(
            $formatter->_format_name( $self->name ),
            ' '
        );
    }

    if ( $parser->has_problems ) {
        $self->_output_test_failure($parser);
    }
    else {
        $formatter->_output("ok\n")
          unless $formatter->really_quiet;
    }

    $self->_output_ruler;

    # $self->SUPER::close_test;
    my $active = $context->{active};

    my @pos = grep { $active->[$_]->name eq $name } 0 .. $#$active;

    die "Can't find myself" unless @pos;
    splice @$active, $pos[0], 1;

    $self->_need_refresh;

    unless (@$active) {

        # $self->formatter->_output("\n");
        delete $shared{$formatter};
    }
}

1;
