package TAP::Parser::SourceDetector;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object ();

use Carp qw( confess );

@ISA = qw(TAP::Object);

=head1 NAME

TAP::Parser::SourceDetector - Base class for TAP source detectors.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # abstract class - not meant to be used directly
  # see TAP::Parser::SourceFactory for preferred usage

  # provides API for subclasses:
  package MySourceDetector;
  # see example below for more details
  sub can_handle  { return $confidence_level }
  sub make_source { return $new_source }

=head1 DESCRIPTION

This is a simple base class for I<source detectors> to inherit from.  It
defines the API used by L<TAP::Parser::SourceFactory> to determine how to get
TAP out of a given source.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<can_handle>

Takes 1 argument: C<$raw_source_ref>.  This is a reference to a scalar, as it
may contain large amounts of data (eg: raw TAP).

Returns a number between 0 & 1 reflecting how confidently the source detector
can handle the given source.  For example, C<0> means the detector cannot
handle the source, C<0.5> means it may be able to, and C<1> means it definitely
can.

=cut

# new() implementation provided by TAP::Object

sub can_handle {
    my ( $class, $raw_source_ref ) = @_;
    confess("'$class' has not defined a 'can_handle' method!");
    return;
}

=head3 C<make_source>

Takes 1 argument: C<$raw_source_ref>.  This is a reference to a scalar, as it
may contain large amounts of data (eg: raw TAP output).

Returns a new L<TAP::Parser::Source> object for use by the L<TAP::Parser>.

=cut

sub make_source {
    my ( $class, $raw_source_ref ) = @_;
    confess("'$class' has not defined a 'make_source' method!");
    return;
}

1;

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

Remember: if you want your subclass to be automatically used by the parser,
you'll have to register it with L<TAP::Parser::SourceFactory/register_detector>.

=head2 Example

  package MySourceDetector;

  use strict;
  use vars '@ISA';

  use MySource; # see TAP::Parser::Source
  use TAP::Parser::SourceFactory;
  use TAP::Parser::SourceDetector;

  @ISA = qw( TAP::Parser::SourceDetector );

  TAP::Parser::SourceFactory->register_detector( __PACKAGE__ );

  sub can_handle {
      my ($class, $raw_source_ref) = @_;
      return 0   unless defined $$raw_source_ref;
      return 0   if $$raw_source_ref =~ /\n/;
      return 1   if $$raw_source_ref eq 'absolutely sure';
      return 0.5 if $$raw_source_ref eq 'not really sure';
      return 0;
  }

  sub make_source {
      my ($class, $raw_source_ref) = @_;
      my $source = MySource->new;
      $source->source([ $raw_source_ref ]);
      return $source;
  }

  1;

=head1 AUTHORS

Steve Purkis

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector::Executable>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::RawTAP>

=cut
