package TAP::Parser::SourceFactory;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object ();
use TAP::Parser::SourceFactory ();

use Carp qw( confess );
use File::Basename qw( fileparse );

@ISA = qw(TAP::Object);

use constant detectors => [];

=head1 NAME

TAP::Parser::SourceFactory - Figures out which SourceDetector objects to use for a given Source

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceFactory;
  my $factory = TAP::Parser::SourceFactory->new({ %config });
  my $detector  = $factory->make_detector( $filename );

=head1 DESCRIPTION

This is a factory class that takes a L<TAP::Parser::Source> and runs it through all the
registered L<TAP::Parser::SourceDetector>s to see which one should handle the source.

If you're a plugin author, you'll be interested in how to L</register_detector>s,
how L</detect_source> works.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

Creates a new factory class:

  my $sf = TAP::Parser::SourceFactory->new( $config );

C<$config> is optional.  If given, sets L</config> and calls L</load_detectors>.

=cut

sub _initialize {
    my ( $self, $config ) = @_;
    $self->config( $config || {} )->load_detectors;
    return $self;
}

=head3 C<register_detector>

Registers a new L<TAP::Parser::SourceDetector> with this factory.

  __PACKAGE__->register_detector( $detector_class );

=cut

sub register_detector {
    my ( $class, $dclass ) = @_;

    confess("$dclass must inherit from TAP::Parser::SourceDetector!")
      unless UNIVERSAL::isa( $dclass, 'TAP::Parser::SourceDetector' );

    my $detectors = $class->detectors;
    push @{$detectors}, $dclass
      unless grep { $_ eq $dclass } @{$detectors};

    return $class;
}

##############################################################################

=head2 Instance Methods

=head3 C<config>

 my $cfg = $sf->config;
 $sf->config({ Perl => { %config } });

Chaining getter/setter for the configuration of the available source detectors.
This is a hashref keyed on detector class whose values contain config to be passed
onto the detectors during detection & creation.  Class names may be fully qualified
or abbreviated, eg:

  # these are equivalent
  $sf->config({ 'TAP::Parser::SourceDetector::Perl' => { %config } });
  $sf->config({ 'Perl' => { %config } });

=cut

sub config {
    my $self = shift;
    return $self->{config} unless @_;
    unless ( 'HASH' eq ref $_[0] ) {
        $self->_croak('Argument to &config must be a hash reference');
    }
    $self->{config} = shift;
    return $self;
}

sub _config_for {
    my ( $self, $sclass ) = @_;
    my ($abbrv_sclass) = ( $sclass =~ /(?:\:\:)?(\w+)$/ );
    my $config = $self->config->{$abbrv_sclass} || $self->config->{$sclass};
    return $config;
}

##############################################################################

=head3 C<load_detectors>

 $sf->load_detectors;

Loads the detector classes defined in L</config>.  For example, given a config:

  $sf->config({
    MySourceDetector => { some => 'config' },
  });

C<load_detectors> will attempt to load the C<MySourceDetector> class by looking in
C<@INC> for it in this order:

  TAP::Parser::SourceDetector::MySourceDetector
  MySourceDetector

C<croak>s on error.

=cut

sub load_detectors {
    my ($self) = @_;
    foreach my $detector ( keys %{ $self->config } ) {
        my $sclass = $self->_load_detector($detector);

        # TODO: store which class we loaded anywhere?
    }
    return $self;
}

sub _load_detector {
    my ( $self, $detector ) = @_;

    my @errors;
    foreach my $sclass ( "TAP::Parser::SourceDetector::$detector", $detector ) {
        return $sclass if UNIVERSAL::isa( $sclass, 'TAP::Parser::SourceDetector' );
        eval "use $sclass";
        if ( my $e = $@ ) {
            push @errors, $e;
            next;
        }
        return $sclass if UNIVERSAL::isa( $sclass, 'TAP::Parser::SourceDetector' );
        push @errors, "detector '$sclass' is not a TAP::Parser::SourceDetector";
    }

    $self->_croak( "Cannot load detector '$detector': " . join( "\n", @errors ) );
}

##############################################################################

=head3 C<make_detector>

Detects and creates a new L<TAP::Parser::SourceDetector> for the L<TAP::Parser::Source>
given (see L</detect_source>).  Dies on error.

=cut

sub make_detector {
    my ( $self, $source ) = @_;

    $self->_croak('no raw source defined!') unless defined $source->raw;

    $source->config( $self->config )
           ->assemble_meta;

    # is the raw source already an object?
    return $source->raw
      if ( $source->meta->{is_object}
	   && UNIVERSAL::isa( $source->raw, 'TAP::Parser::SourceDetector' ) );

    # figure out what kind of source it is
    my $sd_class = $self->detect_source( $source );

    # create it
    my $detector = $sd_class->make_source( $source );

    return $detector;
}


=head3 C<detect_source>

Given a L<TAP::Parser::Source>, detects what kind of source it is and
returns I<one> L<TAP::Parser::SourceDetector> (the most confident one).  Dies
on error.

The detection algorithm works something like this:

  for (@registered_detectors) {
    # ask them how confident they are about handling this source
    $confidence{$detector} = $detector->can_handle( $source )
  }
  # choose the most confident detector

Ties are handled by choosing the first detector.

=cut

sub detect_source {
    my ( $self, $source ) = @_;

    confess('no raw source ref defined!') unless defined $source->raw;

    # find a list of detectors that can handle this source:
    my %detectors;
    foreach my $dclass ( @{ $self->detectors } ) {
        my $confidence = $dclass->can_handle( $source );

        # warn "detector: $dclass: $confidence\n";
        $detectors{$dclass} = $confidence if $confidence;
    }

    if ( !%detectors ) {
        # use Data::Dump qw( pp );
        # warn pp( $meta );

        # error: can't detect source
        my $raw_source_short = substr( ${ $source->raw }, 0, 50 );
        confess("Cannot detect source of '$raw_source_short'!");
        return;
    }

    # if multiple detectors can handle it, choose the most confident one
    my @detectors = (
        map    {$_}
          sort { $detectors{$a} cmp $detectors{$b} }
          keys %detectors
    );

    # this is really useful for debugging detectors:
    if ( $ENV{TAP_HARNESS_SOURCE_FACTORY_VOTES} ) {
        warn(
            "votes: ",
            join( ', ', map {"$_: $detectors{$_}"} @detectors ),
            "\n"
        );
    }

    # return 1st
    return pop @detectors;
}


=head3 C<detectors>

TODO

=cut

1;

__END__

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head2 Example

If we've done things right, you'll probably want to write a new source,
rather than sub-classing this (see L<TAP::Parser::SourceDetector> for that).

But in case you find the need to...

  package MySourceFactory;

  use strict;
  use vars '@ISA';

  use TAP::Parser::SourceFactory;

  @ISA = qw( TAP::Parser::SourceFactory );

  # override source detection algorithm
  sub detect_source {
    my ($self, $raw_source_ref, $meta) = @_;
    # do detective work, using $meta and whatever else...
  }

  1;

=head1 AUTHORS

Steve Purkis

=head1 ATTRIBUTION

Originally ripped off from L<Test::Harness>.

Moved out of L<TAP::Parser> & converted to a factory class to support
extensible TAP source detective work by Steve Purkis.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::File>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::RawTAP>,
L<TAP::Parser::SourceDetector::Handle>,
L<TAP::Parser::SourceDetector::Executable>

=cut

