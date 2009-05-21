package TAP::Parser::Source::Handle;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::Source ();
use TAP::Parser::IteratorFactory ();

@ISA = qw(TAP::Parser::Source);

=head1 NAME

TAP::Parser::Source::Handle - Stream TAP from an IO::Handle or a GLOB.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::Source::Handle;
  my $source = TAP::Parser::Source::Handle->new;
  my $stream = $source->source( \*TAP_FILE )->get_stream;

=head1 DESCRIPTION

Takes raw TAP from the handle given and converts into an iterator.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::Source::Handle->new;

Returns a new C<TAP::Parser::Source::Handle> object.

=cut

# new() implementation supplied by parent class

##############################################################################

=head2 Instance Methods

=head3 C<source>

 my $source = $source->source;
 $source->source( $raw_tap );

Getter/setter for the source.  C<croaks> if it doesn't get a scalar.

=cut

sub source {
    my $self = shift;
    return $self->{source} unless @_;

    my $ref = ref $_[0];
    if (! defined( $ref )) {
        ; # fall through
    } elsif ($ref eq 'GLOB' || UNIVERSAL::isa( $ref, 'IO::Handle' )) {
	$self->{source} = shift;
	return $self;
    }

    $self->_croak('Argument to &source must be a glob ref or an IO::Handle');
}

##############################################################################

=head3 C<get_stream>

 my $stream = $source->get_stream( $iterator_maker );

Returns a L<TAP::Parser::Iterator> for this TAP stream.

=cut

sub get_stream {
    my ( $self, $factory ) = @_;
    return $factory->make_iterator( $self->source );
}

1;

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::Source::Executable>,
L<TAP::Parser::Source::Perl>

=cut
