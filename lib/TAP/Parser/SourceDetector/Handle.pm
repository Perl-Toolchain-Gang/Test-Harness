package TAP::Parser::SourceDetector::Handle;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceFactory  ();
use TAP::Parser::SourceDetector ();
use TAP::Parser::Source::Handle ();

@ISA = qw( TAP::Parser::SourceDetector );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::Handle - Detect raw TAP stored in an IO::Handle or GLOB.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # don't use this directly, use TAP::Parser::SourceFactory !

  # for reference:
  use TAP::Parser::SourceDetector::Handle;
  my $source;
  if (TAP::Parser::SourceDetector::Handle->can_handle( \$raw_source )) {
    $source = TAP::Parser::SourceDetector::Handle->make_source( \$raw_source );
  }

=head1 DESCRIPTION

This is a I<raw TAP stored in an IO Handle> L<TAP::Parser::SourceDetector> -
it's job is to figure out if the I<raw> source it's given is an L<IO::Handle>
or GLOB containing raw TAP output.  See L<TAP::Parser::SourceFactory> for more
details.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=cut

use constant source_class => 'TAP::Parser::Source::Handle';

sub can_handle {
    my ( $class, $raw_source_ref, $meta ) = @_;

    return 0.9 if $meta->{is_object}
      && UNIVERSAL::isa( $raw_source_ref, 'IO::Handle' );

    return 0.8 if $meta->{glob};

    return 0;
}

sub make_source {
    my ( $class, $args ) = @_;
    my $raw_source_ref = $args->{raw_source_ref};
    my $source = $class->source_class->new;
    $source->raw_source( $raw_source_ref );
    return $source;
}

1;

=head1 AUTHORS

Steve Purkis

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector>

=cut
