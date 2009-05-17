package TAP::Parser::SourceDetector::RawTAP;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceFactory  ();
use TAP::Parser::SourceDetector ();

#use TAP::Parser::Source::RawTAP ();

@ISA = qw( TAP::Parser::SourceDetector );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::RawTAP - Raw TAP source detector

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # don't use this directly, use TAP::Parser::SourceFactory !

  # for reference:
  use TAP::Parser::SourceDetector::RawTAP;
  my $source;
  if (TAP::Parser::SourceDetector::RawTAP->can_handle( \$raw_source )) {
    $source = TAP::Parser::SourceDetector::RawTAP->make_source( \$raw_source );
  }

=head1 DESCRIPTION

This is a I<raw TAP output> L<TAP::Parser::SourceDetector> - it's job is to
figure out if the I<raw> source it's given is actually just TAP output.  See
L<TAP::Parser::SourceFactory> for more details.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=cut

use constant source_class => 'TAP::Parser::Source::RawTAP';

sub can_handle {
    my ( $class, $raw_source_ref ) = @_;
    return 0 unless defined $$raw_source_ref;
    return 0.75 if ( $$raw_source_ref =~ /\n/ );
    return 0;
}

sub make_source {
    my ( $class, $raw_source_ref ) = @_;
    my $source = $class->source_class->new($raw_source_ref);

# this should be returned by the source's 'get_stream'
#my $stream = $self->_iterator_for_source( [ split "\n" => $$raw_source_ref ] );
    return $source;
}

1;

=head1 AUTHORS

Steve Purkis

=head1 ATTRIBUTION

Originally from L<Test::Harness>.

Moved from L<TAP::Parser>

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector>

=cut
