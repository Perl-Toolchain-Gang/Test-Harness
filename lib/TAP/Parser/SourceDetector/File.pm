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

=head3 C<can_handle>

  my $vote = $class->can_handle( $source );

Only votes if $source looks like a regular file.  Casts the following votes:

  1.0 if it's a .tap file
  1.0 if it has an extension matching any given in user config.

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

  my $iterator = $class->make_iterator( $source );

Returns a new L<TAP::Parser::Iterator::Stream> for the source.  C<croak>s
on error.

=cut

sub make_iterator {
    my ( $class, $source ) = @_;

    $class->_croak('$source->raw must be a scalar ref')
      unless $source->meta->{is_scalar};

    my $file = ${ $source->raw };
    my $fh;
    open( $fh, '<', $file )
      or $class->_croak("error opening TAP source file '$file': $!");
    return $class->iterator_class->new( $fh );
}

=head3 C<iterator_class>

The class of iterator to use, override if you're sub-classing.  Defaults
to L<TAP::Parser::Iterator::Stream>.

=cut

use constant iterator_class => 'TAP::Parser::Iterator::Stream';

1;

__END__

=head1 CONFIGURATION

  {
   extensions => [ @case_insensitive_exts_to_match ]
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
