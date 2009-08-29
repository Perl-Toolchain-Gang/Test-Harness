package TAP::Parser::SourceDetector;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object ();
use TAP::Parser::Iterator ();

@ISA = qw(TAP::Object);

=head1 NAME

TAP::Parser::SourceDetector - Base class for different TAP source detectors

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # abstract class - don't use directly!
  # see TAP::Parser::SourceFactory for general usage

  # must be sub-classed for use
  package MySourceDetector;
  use base qw( TAP::Parser::SourceDetector );
  sub can_handle    { return $confidence_level }
  sub make_iterator { return $iterator }

  # see example below for more details

=head1 DESCRIPTION

This is an abstract base class for L<TAP::Parser::Source> detectors / handlers.

A C<TAP::Parser::SourceDetector> does whatever is necessary to produce & capture
a stream of TAP from the I<raw> source, and package it up in a
L<TAP::Parser::Iterator> for the parser to consume.

C<SourceDetectors> must implement the I<source detection & handling> interface
used by L<TAP::Parser::SourceFactory>.  At 2 methods, the interface is pretty
simple: L</can_handle> and L</make_source>.

Unless you're writing a new L<TAP::Parser::SourceDetector>, a plugin, or
subclassing L<TAP::Parser>, you probably won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::SourceDetector->new;

Returns a new C<TAP::Parser::SourceDetector> object.

=cut

# new() implementation supplied by TAP::Object

sub _initialize {
    my ($self) = @_;
    $self->config( {} );
    return $self;
}

##############################################################################

=head3 C<can_handle>

I<Abstract method>.

  my $vote = $class->can_handle( $source );

C<$source> is a L<TAP::Parser::Source>.

Returns a number between C<0> & C<1> reflecting how confidently the raw source
can be handled.  For example, C<0> means the source cannot handle it, C<0.5>
means it may be able to, and C<1> means it definitely can.  See
L<TAP::Parser::SourceFactory/detect_source> for details on how this is used.

=cut

sub can_handle {
    my ( $class, $args ) = @_;
    $class->_confess("'$class' has not defined a 'can_handle' method!");
    return;
}

=head3 C<make_iterator>

I<Abstract method>.

  my $iterator = $class->make_iterator( $source );

C<$source> is a L<TAP::Parser::Source>.

Returns a new L<TAP::Parser::Iterator> object for use by the L<TAP::Parser>.
C<croak>s on error.

=cut

sub make_iterator {
    my ( $class, $args ) = @_;
    $class->_confess("'$class' has not defined a 'make_iterator' method!");
    return;
}

##############################################################################

=head2 Instance Methods

=head3 C<raw_source>

 my $raw_source = $source->raw_source;
 $source->raw_source( $some_value );

Chaining getter/setter for the raw TAP source.

=head3 C<source>

I<Deprecated.>

Synonym for L</raw_source>.

=head3 C<config>

 my $config = $source->config;
 $source->config({ %some_value });

Chaining getter/setter for the source's configuration, if any.  This defaults
to an empty hashref.

=head3 C<merge>

  my $merge = $source->merge;

Chaining getter/setter for the flag that dictates whether STDOUT and STDERR
should be merged (where appropriate).

=cut

sub raw_source {
    my $self = shift;
    return $self->{raw_source} unless @_;
    $self->{raw_source} = shift;
    return $self;
}

sub source {
    my $self = shift;
    return $self->raw_source(@_);
}

sub config {
    my $self = shift;
    return $self->{config} unless @_;
    $self->{config} = shift;
    return $self;
}

sub merge {
    my $self = shift;
    return $self->{merge} unless @_;
    $self->{merge} = shift;
    return $self;
}

##############################################################################

=head3 C<get_stream>

I<Deprecated.>  I<Abstract method>.

 my $stream = $source->get_stream( $iterator_maker );

Returns a L<TAP::Parser::Iterator> stream of the output generated from the
raw TAP C<source>.

The C<$iterator_maker> given must be an object that implements a
C<make_iterator> method to capture the TAP stream.  Typically this is a
L<TAP::Parser> instance.

=cut

sub get_stream {
    my ( $self, $factory ) = @_;
    my $class = ref($self) || $self;
    $self->_croak("Abstract method 'get_stream' not implemented for $class!");
}

1;

__END__

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview, and any
of the subclasses that ship with this module as an example.  What follows is
a quick overview.

Start by familiarizing yourself with L<TAP::Parser::Source> and
L<TAP::Parser::SourceFactory>.

It's important to point out that if you want your subclass to be automatically
used by L<TAP::Parser> you'll have to and make sure it gets loaded somehow.
If you're using L<prove> you can write an L<App::Prove> plugin.  If you're
using L<TAP::Parser> or L<TAP::Harness> directly (eg. through a custom script,
L<ExtUtils::MakeMaker>, or L<Module::Build>) you can use the C<config> option
which will cause L<TAP::Parser::SourceFactory/load_sources> to load your
subclass).

Don't forget to register your class with
L<TAP::Parser::SourceFactory/register_detector>.

=head2 Example

  package MySourceDetector;

  use strict;
  use vars '@ISA'; # compat with older perls

  use MySourceDetector; # see TAP::Parser::SourceDetector
  use TAP::Parser::SourceFactory;

  @ISA = qw( TAP::Parser::SourceDetector );

  TAP::Parser::SourceFactory->register_detector( __PACKAGE__ );

  sub can_handle {
      my ( $class, $src ) = @_;
      my $meta   = $src->meta;
      my $config = $src->config_for( $class );

      if ($config->{accept_all}) {
          return 1.0;
      } elsif (my $file = $meta->{file}) {
          return 0.0 unless $file->{exists};
          return 1.0 if $file->{lc_ext} eq '.tap';
          return 0.9 if $file->{shebang} && $file->{shebang} =~ /^#!.+tap/;
          return 0.5 if $file->{text};
          return 0.1 if $file->{binary};
      } elsif ($meta->{scalar}) {
          return 0.8 if $$raw_source_ref =~ /\d\.\.\d/;
          return 0.6 if $meta->{has_newlines};
      } elsif ($meta->{array}) {
          return 0.8 if $meta->{size} < 5;
          return 0.6 if $raw_source_ref->[0] =~ /foo/;
          return 0.5;
      } elsif ($meta->{hash}) {
          return 0.6 if $raw_source_ref->{foo};
          return 0.2;
      }

      return 0;
  }

  sub make_iterator {
      my ($class, $source) = @_;
      # this is where you manipulate the source and
      # capture the stream of TAP in an iterator
      # either pick a TAP::Parser::Iterator::* or write your own...
      my $iterator = TAP::Parser::Iterator::Array->new([ 'foo', 'bar' ]);
      return $iterator;
  }

  1;

=head1 AUTHORS

TAPx Developers.

Source detection stuff added by Steve Purkis

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::Iterator>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector::Executable>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::File>,
L<TAP::Parser::SourceDetector::Handle>,
L<TAP::Parser::SourceDetector::RawTAP>

=cut

