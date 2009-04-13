package TAP::Parser::SourceFactory;

use strict;
use vars qw($VERSION @ISA %DETECTORS);

use TAP::Object ();

use Carp qw( confess );

@ISA = qw(TAP::Object);

use constant detectors => [];


=head1 NAME

TAP::Parser::SourceFactory - Internal TAP::Parser Source

=head1 VERSION

Version 3.17

=cut

$VERSION = '3.17';

=head1 SYNOPSIS

  use TAP::Parser::SourceFactory;
  my $factory = TAP::Parser::SourceFactory->new;
  my $source  = $factory->make_source( $filename );

=head1 DESCRIPTION

This is a factory class for different types of TAP sources.  If you're reading
this, you're likely either a plugin author who will be interested in how to
L</register_detector>s, or you're just interested in how a TAP source's type
is determined (see L</detect_source>);

=head1 METHODS

=head2 Class Methods

=head3 C<new>

Creates a new factory class.

=cut

sub _initialize {
    my ($self, @args) = @_;
    # initialize your object
    return $self;
}

=head3 C<register_detector>

Registers a new L<TAP::Parser::SourceDetector> with this factory.

  __PACKAGE__->register_detector( $detector_class );

=cut

# either 'registry' approach, or scan @INC & load plugins.
# was thinking 'detectors' ala:
# TAP::Parser::SourceDetector::Archive, etc...
sub register_detector {
    my ($class, $dclass) = @_;

    confess( "$dclass must inherit from TAP::Parser::SourceDetector!" )
      unless UNIVERSAL::isa( $dclass, 'TAP::Parser::SourceDetector' );

    my $detectors = $class->detectors;
    push @{ $detectors }, $dclass
      unless grep { $_ eq $dclass } @{ $detectors };

    return $class;
}


=head2 Instance Methods

=head3 C<make_source>

Detects and creates a new L<TAP::Parser::Source> for the C<$raw_source_ref>
given (see L</detect_source>).  Dies on error.

=cut

sub make_source {
    my ($self, $raw_source_ref) = @_;

    confess( 'no raw source ref defined!' ) unless defined $raw_source_ref;

    # is the raw source already an object?
    return $$raw_source_ref
      if (ref( $$raw_source_ref ) &&
	  UNIVERSAL::isa( $$raw_source_ref, 'TAP::Parser::Source' ));

    # figure out what kind of source it is
    my $source_detector = $self->detect_source( $raw_source_ref );
    my $source = $source_detector->make_source( $raw_source_ref );

    return $source;
}


=head3 C<detect_source>

Given a reference to the raw source, detects what kind of source it is and
returns I<one> L<TAP::Parser::SourceDetector> (the most confident one).  Dies
on error.

The detection algorithm works something like this:

  for all registered detectors
    asking them how confident they are about handling this source
  choose the most confident detector

=cut

sub detect_source {
    my ($self, $raw_source_ref) = @_;

    confess( 'no raw source ref defined!' ) unless defined $raw_source_ref;

    # find a list of detectors that can handle this source:
    my %detectors;
    foreach my $dclass (@{ $self->detectors }) {
	my $confidence = $dclass->can_handle( $raw_source_ref );
	$detectors{$dclass} = $confidence if $confidence;
    }

    if (! %detectors) {
	# error: can't detect source
	my $raw_source_short = substr( $$raw_source_ref, 0, 50 );
	confess( "Couldn't detect source of '$raw_source_short'!" );
	return;
    }

    # if multiple detectors can handle it, choose the most confident one
    my @detectors = ( map { $_ }
		      sort { $detectors{$a} cmp $detectors{$b} }
		      keys %detectors );

    # return 1st detector
    return pop @detectors;
}


1;

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head2 Example

If I've done things right, you'll probably want to write a new detector,
rather than sub-classing this (see L<TAP::Parser::SourceDetector> for that).

But in case you find the need to...

  package MySourceFactory;

  use strict;
  use vars '@ISA';

  use TAP::Parser::SourceFactory;

  @ISA = qw( TAP::Parser::SourceFactory );

  # override source detection algorithm
  sub detect_source {
    my ($self, $raw_source_ref) = @_;
    # do detective work...
  }

  1;

=head1 AUTHORS

Steve Purkis

=head1 ATTRIBUTION

Originally ripped off from L<Test::Harness>.

Moved out of L<TAP::Parser> & converted to a factory class to support
extensible TAP source detective work.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::RawTAP>,
L<TAP::Parser::SourceDetector::Executable>

=cut

