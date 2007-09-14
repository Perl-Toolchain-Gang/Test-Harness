package TAP::Formatter::Console::ParallelSession;

use strict;
use Benchmark;
use File::Spec;
use File::Path;
use TAP::Formatter::Console::Session;
use Carp;

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

Version 2.99_03

=cut

$VERSION = '2.99_03';

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
    my $self      = shift;
    my $formatter = $self->formatter;
    my $context   = $shared{$formatter};
    if ( delete $context->{need_refresh} ) {
        for my $test ( @{ $context->{active} } ) {
            $formatter->_output( $test->_pretty_name, "\n" );
        }
        $formatter->_output("\n");
    }
}

=head3 C<result>

Called by the harness for each line of TAP it receives.

=cut

sub result {
    my ( $self, $result ) = @_;

    $self->_refresh;

    # print ".";
}

=head3 C<close_test>

=cut

sub close_test {
    my $self = shift;
    my $name = $self->name;
    $self->formatter->_output( "Ending ", $name, "\n" );

    # $self->SUPER::close_test;
    my $formatter = $self->formatter;
    my $context   = $shared{$formatter};
    my $active    = $context->{active};

    my @pos = grep { $active->[$_]->name eq $name } 0 .. $#$active;

    die "Can't find myself" unless @pos;
    splice @$active, $pos[0], 1;

    $self->_need_refresh;

    unless (@$active) {
        warn "Bye bye!\n";
        delete $shared{$formatter};
    }
}

1;
