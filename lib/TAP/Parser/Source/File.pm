package TAP::Parser::Source::File;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::Source ();
use TAP::Parser::SourceFactory ();
use TAP::Parser::IteratorFactory ();

@ISA = qw(TAP::Parser::Source);

TAP::Parser::SourceFactory->register_source(__PACKAGE__);

=head1 NAME

TAP::Parser::Source::File - Stream TAP from a text file.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::Source::File;
  my $source = TAP::Parser::Source::File->new;
  my $stream = $source->source (\"1..1\nok 1\n" )->get_stream;

=head1 DESCRIPTION

This is a I<raw TAP stored in a file> L<TAP::Parser::Source> - it has 2 jobs:

1. Figure out if the I<raw> source it's given is a file containing raw TAP
output.  See L<TAP::Parser::SourceFactory> for more details.

2. Takes raw TAP from the text file given, and converts into an iterator.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::Source::File->new;

Returns a new C<TAP::Parser::Source::File> object.

=cut

# new() implementation supplied by parent class

sub can_handle {
    my ( $class, $raw_source_ref, $meta, $config ) = @_;

    return 0 unless $meta->{is_file};
    my $file = $meta->{file};
    return 1 if $file->{lc_ext} eq '.tap';

    if (my $exts = $config->{extensions}) {
	return 1 if grep {lc($_) eq $file->{lc_ext}} @$exts;
    }

    return 0;
}

sub make_source {
    my ( $class, $args ) = @_;
    my $raw_source_ref = $args->{raw_source_ref};
    my $source = $class->new;
    $source->raw_source( $raw_source_ref );
    return $source;
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
    if (! defined( $ref )) {
        return $self->SUPER::raw_source( $_[0] );
    } elsif ($ref eq 'SCALAR') {
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
      or $self->_croak( "error opening TAP source file '$file': $!" );
    return $factory->make_iterator( $fh );
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
L<TAP::Parser::Source>,
L<TAP::Parser::Source::Executable>,
L<TAP::Parser::Source::Perl>

=cut
