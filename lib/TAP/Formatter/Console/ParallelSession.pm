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
    ( $shared{$formatter} ||= $self->_create_shared_context )->{count}++;
}

sub _create_shared_context {
    my $self = shift;
    return { count => 0 };
}

# Subclasses beware. TODO: this smells bad.
sub DESTROY {
    my $self      = shift;
    my $formatter = $self->formatter;

    # We really shouldn't be doing our own reference counting...
    if ( exists $shared{$formatter} && 0 == --$shared{$formatter}->{count} ) {
        delete $shared{$formatter};
    }
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

=head3 C<result>

Called by the harness for each line of TAP it receives.

=cut

sub result {
    my ( $self, $result ) = @_;
    $self->SUPER::result($result);
}

1;
