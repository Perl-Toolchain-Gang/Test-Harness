package TAP::Parser::SourceDetector::Handle;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceDetector          ();
use TAP::Parser::SourceFactory   ();
use TAP::Parser::IteratorFactory ();

@ISA = qw(TAP::Parser::SourceDetector);

TAP::Parser::SourceFactory->register_source(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::Handle - Stream TAP from an IO::Handle or a GLOB.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceDetector::Handle;
  my $source = TAP::Parser::SourceDetector::Handle->new;
  my $stream = $source->raw_source( \*TAP_FILE )->get_stream;

=head1 DESCRIPTION

This is a I<raw TAP stored in an IO Handle> L<TAP::Parser::SourceDetector> class.  It
has 2 jobs:

1. Figure out if the I<raw> source it's given is an L<IO::Handle> or GLOB
containing raw TAP output.  See L<TAP::Parser::SourceFactory> for more details.

2. Takes raw TAP from the handle/GLOB given and converts into an iterator.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::SourceDetector::Handle->new;

Returns a new C<TAP::Parser::SourceDetector::Handle> object.

=cut

# new() implementation supplied by parent class

=head3 C<can_handle>

=cut

sub can_handle {
    my ( $class, $raw_source_ref, $meta ) = @_;

    return 0.9
      if $meta->{is_object}
          && UNIVERSAL::isa( $raw_source_ref, 'IO::Handle' );

    return 0.8 if $meta->{glob};

    return 0;
}

=head3 C<make_source>

=cut

sub make_source {
    my ( $class, $args ) = @_;
    my $raw_source_ref = $args->{raw_source_ref};
    my $source         = $class->new;
    $source->raw_source($raw_source_ref);
    return $source;
}

##############################################################################

=head2 Instance Methods

=head3 C<raw_source>

 my $raw_source = $source->raw_source;
 $source->raw_source( $raw_tap );

Getter/setter for the raw_source.  C<croaks> if it doesn't get a scalar or
L<IO::Handle> object.

=cut

sub raw_source {
    my $self = shift;
    return $self->SUPER::raw_source unless @_;

    my $ref = ref $_[0];
    if ( !defined($ref) ) {
        ;    # fall through
    }
    elsif ( $ref eq 'GLOB' || UNIVERSAL::isa( $ref, 'IO::Handle' ) ) {
        return $self->SUPER::raw_source(shift);
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
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::Executable>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::File>,
L<TAP::Parser::SourceDetector::RawTAP>

=cut
