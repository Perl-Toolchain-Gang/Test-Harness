package TAP::Parser::IteratorFactory;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object                    ();
use TAP::Parser::Iterator::Array   ();
use TAP::Parser::Iterator::Stream  ();
use TAP::Parser::Iterator::Process ();

@ISA = qw(TAP::Object);

=head1 NAME

TAP::Parser::IteratorFactory - Internal TAP::Parser Iterator

=head1 VERSION

Version 3.12

=cut

$VERSION = '3.12';

=head1 SYNOPSIS

  use TAP::Parser::IteratorFactory;
  my $iter = TAP::Parser::IteratorFactory->new(\*TEST);
  my $iter = TAP::Parser::IteratorFactory->new(\@array);
  my $iter = TAP::Parser::IteratorFactory->new(\%hash);

  my $line = $iter->next;

Originally ripped off from L<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a factory class for simple iterator wrappers for arrays and
filehandles.

=head2 Class Methods

=head3 C<new>

Create an iterator.  The type of iterator created depends on
the arguments to the constructor:

  my $iter = TAP::Parser::Iterator->new( $filehandle );

Creates a I<stream> iterator (see L</make_stream_iterator>).

  my $iter = TAP::Parser::Iterator->new( $array_reference );

Creates an I<array> iterator (see L</make_array_iterator>).

  my $iter = TAP::Parser::Iterator->new( $hash_reference );

Creates a I<process> iterator (see L</make_process_iterator>).

=cut

# override new() to do some custom factory class action...

sub new {
    my ( $proto, $thing ) = @_;

    my $ref = ref $thing;
    if ( $ref eq 'GLOB' || $ref eq 'IO::Handle' ) {
	return $proto->make_stream_iterator($thing);
    }
    elsif ( $ref eq 'ARRAY' ) {
	return $proto->make_array_iterator($thing);
    }
    elsif ( $ref eq 'HASH' ) {
	return $proto->make_process_iterator($thing);
    }
    else {
        die "Can't iterate with a $ref";
    }
}


=head3 C<make_stream_iterator>

Make a new stream iterator and return it.  Passes through any arguments given.
Defaults to a L<TAP::Parser::Iterator::Stream>.

=head3 C<make_array_iterator>

Make a new array iterator and return it.  Passes through any arguments given.
Defaults to a L<TAP::Parser::Iterator::Array>.

=head3 C<make_process_iterator>

Make a new process iterator and return it.  Passes through any arguments given.
Defaults to a L<TAP::Parser::Iterator::Process>.

=cut

sub make_stream_iterator {
    my $proto = shift;
    TAP::Parser::Iterator::Stream->new( @_ );
}

sub make_array_iterator {
    my $proto = shift;
    TAP::Parser::Iterator::Array->new( @_ );
}

sub make_process_iterator {
    my $proto = shift;
    TAP::Parser::Iterator::Process->new( @_ );
}


1;

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,
L<TAP::Parser::Iterator::Array>,
L<TAP::Parser::Iterator::Stream>,
L<TAP::Parser::Iterator::Process>,

=cut

