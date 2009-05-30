package TAP::Parser::Source;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object                  ();
use TAP::Parser::IteratorFactory ();

@ISA = qw(TAP::Object);

=head1 NAME

TAP::Parser::Source - Base class for different TAP sources

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # abstract class - don't use directly!
  # see TAP::Parser::SourceFactory for general usage

  # must be sub-classed for use
  package MySource;
  use base qw( TAP::Parser::Source );
  sub can_handle  { return $confidence_level }
  sub make_source { return $new_source }
  sub get_stream  { return $iterator }

  # see example below for more details

=head1 DESCRIPTION

This is the base class for a TAP I<source>, i.e. something that produces a
stream of TAP for the parser to consume, such as an executable file, a text
file, an archive, an IO handle, a database, etc.  A C<TAP::Parser::Source>
is a wrapper around the I<raw> TAP source that does whatever is necessary to
capture the stream of TAP produced, and make it available to the Parser
through a L<TAP::Parser::Iterator> object.

C<Sources> must also implement the I<source detection> interface used by
L<TAP::Parser::SourceFactory> to determine how to get TAP out of a given
I<raw> source.  See L</can_handle> and L</make_source> for that.

Unless you're writing a new L<TAP::Parser::Source>, a plugin or subclassing
L<TAP::Parser>, you probably won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::Source->new;

Returns a new C<TAP::Parser::Source> object.

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

  my $vote = $class->can_handle( $raw_source_ref, $meta, $config );
  # TODO: or preferably:
  my $vote = $source->can_handle({
      raw_source_ref => $raw_source_ref,
      meta           => { %meta },
      $config        => { %config },
  });

C<$raw_source_ref> is a reference as it may contain large amounts of data
(eg: raw TAP), not to mention different data types.  C<$meta> is a hashref
containing meta data about the source itself (see
L<TAP::Parser::SourceFactory/assemble_meta>).  C<$config> is a hashref
containing any configuration given by the user (how it's used is up to you).

Returns a number between C<0> & C<1> reflecting how confidently the raw source
can be handled.  For example, C<0> means the source cannot handle it, C<0.5>
means it may be able to, and C<1> means it definitely can.  See
L<TAP::Parser::SourceFactory/detect_source> for details on how this is used.

=cut

sub can_handle {
    my ( $class, $args ) = @_;
    confess("'$class' has not defined a 'can_handle' method!");
    return;
}


=head3 C<make_source>

I<Abstract method>.  Takes a hashref as an argument:

  my $source = $class->make_source({
      raw_source_ref => $raw_source_ref,
      config         => { %config },
      merge          => $bool,
      perl_test_args => [ ... ],
      switches       => [ ... ],
      meta           => { %meta },
      ...
  });

At the very least, C<raw_source_ref> is I<required>.  This is a reference as
it may contain large amounts of data (eg: raw TAP output), not to mention
different data types.

Returns a new L<TAP::Parser::Source> object for use by the L<TAP::Parser>.
C<croak>s on error.

This is used primarily by L<TAP::Parser::SourceFactory>.

=cut

sub make_source {
    my ( $class, $args ) = @_;
    confess("'$class' has not defined a 'make_source' method!");
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

I<Abstract method>.

 my $stream = $source->get_stream( $iterator_maker );

Returns a L<TAP::Parser::Iterator> stream of the output generated from the
raw TAP C<source>.

The C<$iterator_maker> given must be an object that implements a
C<make_iterator> method to capture the TAP stream.  Typically this is a
L<TAP::Parser> instance, rather than a L<TAP::Parser::IteratorFactory>.

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

Start by familiarizing yourself with L<TAP::Parser::SourceFactory>, and
L<TAP::Parser::IteratorFactory>.

It's important to point out that if you want your subclass to be automatically
used by L<TAP::Parser> you'll have to and make sure it gets loaded somehow.
If you're using L<prove> you can write an L<App::Prove> plugin.  If you're
using L<TAP::Parser> or L<TAP::Harness> directly (eg. through a custom script,
or even L<Module::Build>) you can use the C<config> option which will cause
L<TAP::Parser::SourceFactory/load_sources> to load your subclass).

Don't forget to register your class with
L<TAP::Parser::SourceFactory/register_source>.

=head2 Example

  package MySource;

  use strict;
  use vars '@ISA'; # compat with older perls

  use MySource; # see TAP::Parser::Source
  use TAP::Parser::SourceFactory;

  @ISA = qw( TAP::Parser::Source );

  TAP::Parser::SourceFactory->register_source( __PACKAGE__ );

  sub can_handle {
      my ($class, $raw_source_ref, $meta, $config) = @_;

      if ($config->{accept_all}) {
          return 1.0;
      } elsif (my $file = $meta->{file}) {
          return 0.0 unless $file->{exists};
          return 1.0 if $file->{lc_ext} eq '.tap';
          return 0.9 if $file->{text};
          return 0.1 if $file->{binary};
      } elsif ($meta->{scalar}) {
          return 0.9 if $meta->{has_newlines};
          return 0.8 if $$raw_source_ref =~ /\d\.\.\d/;
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

  sub make_source {
      my ($class, $args) = @_;
      my $source = MySource->new;
      # do anything special here...
      $source->merge( $args->{merge} );
             ->raw_source( $args->{raw_source_ref} );
      return $source;
  }

  sub get_stream {
      my ($self, $factory) = @_;
      return $factory->make_iterator( $self->source );
  }

  1;

=head1 AUTHORS

TAPx Developers.

Source detection stuff added by Steve Purkis

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::Source::Executable>,
L<TAP::Parser::Source::Perl>,
L<TAP::Parser::Source::File>,
L<TAP::Parser::Source::Handle>,
L<TAP::Parser::Source::RawTAP>

=cut

