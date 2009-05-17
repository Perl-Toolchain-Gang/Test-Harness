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

  # see TAP::Parser::SourceFactory for general usage

  # must be sub-classed for use
  package MySource;
  use vars '@ISA';
  use TAP::Parser::Source ();
  @ISA = qw( TAP::Parser::Source MyCustom );
  sub get_stream {
    my ( $self, $factory ) = @_;
    # make an iterator, maybe using $factory
  }

=head1 DESCRIPTION

This is the base class for a TAP I<source>, i.e. something that produces a
stream of TAP for the parser to consume, such as an executable file, a text
file, an archive, a database, etc.  A C<TAP::Parser::Source> exists as a
wrapper around the I<raw> TAP source to do whatever is necessary to capture
the stream of TAP produced, and make it available to the Parser through a
L<TAP::Parser::Iterator> object.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::Source->new;

Returns a new C<TAP::Parser::Source> object.

=cut

# new() implementation supplied by TAP::Object

##############################################################################

=head2 Instance Methods

=head3 C<source>

 my $source = $source->source;
 $source->source($some_value);

Chaining getter/setter for the raw TAP source.

=head3 C<merge>

  my $merge = $source->merge;

Chaining getter/setter for the flag that dictates whether STDOUT and STDERR
should be merged (where appropriate).

=cut

sub source {
    my $self = shift;
    return $self->{source} unless @_;
    $self->{source} = shift;
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

B<Note:> this method is abstract and should be overridden.

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

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview, and
L<TAP::Parser::Source::Executable> as an example of how to sub-class.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source::Executable>,
L<TAP::Parser::Source::Perl>

=cut

