package TAP::Parser::SourceDetector::File;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceDetector   ();
use TAP::Parser::SourceFactory    ();
use TAP::Parser::Iterator::Stream ();

@ISA = qw(TAP::Parser::SourceDetector);

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::File - Stream TAP from a text file.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceDetector::File;
  my $source = TAP::Parser::SourceDetector::File->new;
  my $stream = $source->source (\"1..1\nok 1\n" )->get_stream;

=head1 DESCRIPTION

This is a I<raw TAP stored in a file> L<TAP::Parser::SourceDetector> - it has 2 jobs:

1. Figure out if the I<raw> source it's given is a file containing raw TAP
output.  See L<TAP::Parser::SourceFactory> for more details.

2. Takes raw TAP from the text file given, and converts into an iterator.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::SourceDetector::File->new;

Returns a new C<TAP::Parser::SourceDetector::File> object.

=cut

# new() implementation supplied by parent class

=head3 C<can_handle>

=cut

sub can_handle {
    my ( $class, $src ) = @_;
    my $meta   = $src->meta;
    my $config = $src->config_for( $class );

    return 0 unless $meta->{is_file};
    my $file = $meta->{file};
    return 1 if $file->{lc_ext} eq '.tap';

    if ( my $exts = $config->{extensions} ) {
        return 1 if grep { lc($_) eq $file->{lc_ext} } @$exts;
    }

    return 0;
}

=head3 C<make_iterator>

=cut

sub make_iterator {
    my ( $class, $src ) = @_;
    my $source = $class->new;
    $source->raw_source( $src->raw );
    return $source->get_stream;
}

##############################################################################

=head2 Instance Methods

=head3 C<raw_source>

 my $source = $source->source;
 $source->source( $raw_tap );

Getter/setter for the raw source.  C<croaks> if it doesn't get a scalar.

=cut

sub raw_source {
    my $self = shift;
    return $self->SUPER::raw_source unless @_;

    my $ref = ref $_[0];
    if ( !defined($ref) ) {
        return $self->SUPER::raw_source( $_[0] );
    }
    elsif ( $ref eq 'SCALAR' ) {
        return $self->SUPER::raw_source( ${ $_[0] } );
    }

    $self->_croak('Argument to &raw_source must be a scalar or scalar ref');
}

##############################################################################

=head3 C<get_stream>

 my $stream = $source->get_stream( $iterator_maker );

Returns a L<TAP::Parser::Iterator> for this TAP stream.

=cut

sub get_stream {
    my ( $self, $factory ) = @_;
    my $file = $self->raw_source;
    my $fh;
    open( $fh, '<', $file )
      or $self->_croak("error opening TAP source file '$file': $!");
    return TAP::Parser::Iterator::Stream->new( $fh );
}

1;

__END__

=head1 CONFIGURATION

  {
   extensions => [ @list_of_exts_to_match ]
  }

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::Executable>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::Handle>,
L<TAP::Parser::SourceDetector::RawTAP>

=cut
