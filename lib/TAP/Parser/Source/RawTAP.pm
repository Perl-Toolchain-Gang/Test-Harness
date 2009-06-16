package TAP::Parser::Source::RawTAP;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::Source          ();
use TAP::Parser::SourceFactory   ();
use TAP::Parser::IteratorFactory ();

@ISA = qw(TAP::Parser::Source);

TAP::Parser::SourceFactory->register_source(__PACKAGE__);

=head1 NAME

TAP::Parser::Source::RawTAP - Stream output from raw TAP in a scalar/array ref.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::Source::RawTAP;
  my $source = TAP::Parser::Source::RawTAP->new;
  my $stream = $source->source( \"1..1\nok 1\n" )->get_stream;

=head1 DESCRIPTION

This is a I<raw TAP output> L<TAP::Parser::Source> - it has 2 jobs:

1. Figure out if the I<raw> source it's given is actually just TAP output.
See L<TAP::Parser::SourceFactory> for more details.

2. Takes raw TAP and converts into an iterator.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::Source::RawTAP->new;

Returns a new C<TAP::Parser::Source::RawTAP> object.

=cut

# new() implementation supplied by parent class

sub can_handle {
    my ( $class, $raw_source_ref, $meta ) = @_;
    return 0 if $meta->{file};
    if ( $meta->{scalar} ) {
        return 0 unless $meta->{has_newlines};
        return 0.9 if $$raw_source_ref =~ /\d\.\.\d/;
        return 0.7 if $$raw_source_ref =~ /ok/;
        return 0.6;
    }
    elsif ( $meta->{array} ) {
        return 0.5;
    }
    return 0;
}

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
 $source->raw_source( \$raw_tap );

Getter/setter for the raw_source.  C<croaks> if it doesn't get a scalar or
array ref.

=cut

sub raw_source {
    my $self = shift;
    if (@_) {
        my $ref = ref $_[0];
        if ( !defined($ref) ) {
            ;    # fall through
        }
        elsif ( $ref eq 'SCALAR' ) {
            my $scalar_ref = shift;
            return $self->SUPER::raw_source( [ split "\n" => $$scalar_ref ] );
        }
        elsif ( $ref eq 'ARRAY' ) {
            return $self->SUPER::raw_source(shift);
        }
        $self->_croak(
            'Argument to &raw_source must be a scalar or array reference');
    }
    return $self->SUPER::raw_source;
}

##############################################################################

=head3 C<get_stream>

 my $stream = $source->get_stream( $iterator_maker );

Returns a L<TAP::Parser::Iterator> for this TAP stream.

=cut

sub get_stream {
    my ( $self, $factory ) = @_;
    return $factory->make_iterator( $self->raw_source );
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
