package TAP::Parser::Iterator::Stream;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::Iterator ();

@ISA = 'TAP::Parser::Iterator';

=head1 NAME

TAP::Parser::Iterator::Stream - Internal TAP::Parser Iterator

=head1 VERSION

Version 3.12

=cut

$VERSION = '3.12';

=head1 SYNOPSIS

  # see TAP::Parser::IteratorFactory for preferred usage

  # to use directly:
  use TAP::Parser::Iterator::Stream;
  my $it = TAP::Parser::Iterator::Stream->new(\*TEST);

  my $line = $it->next;

Originally ripped off from L<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for filehandles.

=head2 Class Methods

=head3 C<new>

Create an iterator.  Expects one argument containing a filehandle.

=cut

# new() implementation supplied by TAP::Object

sub _initialize {
    my ( $self, $thing ) = @_;
    $self->{fh} = $thing;
    return $self;
}


=head2 Instance Methods

=head3 C<next>

Iterate through it, of course.

=head3 C<next_raw>

Iterate raw input without applying any fixes for quirky input syntax.

=head3 C<wait>

Get the wait status for this iterator. Always returns zero.

=head3 C<exit>

Get the exit status for this iterator. Always returns zero.

=cut

sub wait { shift->exit }
sub exit { shift->{fh} ? () : 0 }

sub next_raw {
    my $self = shift;
    my $fh   = $self->{fh};

    if ( defined( my $line = <$fh> ) ) {
        chomp $line;
        return $line;
    }
    else {
        $self->_finish;
        return;
    }
}

sub _finish {
    my $self = shift;
    close delete $self->{fh};
}

1;

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,
L<TAP::Parser::IteratorFactory>,

=cut

