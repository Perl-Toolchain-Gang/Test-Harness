package TAP::Parser::SourceDetector::Executable;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceFactory  ();
use TAP::Parser::SourceDetector ();

# TODO
#use TAP::Parser::Source::Executable ();

@ISA = qw( TAP::Parser::SourceDetector );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::Executable - Executable TAP source detector

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # don't use this directly, use TAP::Parser::SourceFactory !

  # for reference:
  use TAP::Parser::SourceDetector::Executable;
  my $source;
  if (TAP::Parser::SourceDetector::Executable->can_handle( \$raw_source )) {
    $source = TAP::Parser::SourceDetector::Executable->make_source( \$raw_source );
  }

=head1 DESCRIPTION

This is an I<executable> L<TAP::Parser::SourceDetector> - it's job is to figure
out if the I<raw> source it's given is actually an executable file.  See
L<TAP::Parser::SourceFactory> for more details.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=cut

use constant source_class => 'TAP::Parser::Source::Executable';

sub can_handle {
    my ( $class, $raw_source_ref, $meta ) = @_;
    return 0 unless $meta->{is_file};
    my $file = $meta->{file};
    # Note: we go in low so we can be out-voted
    return 0.8 if $file->{lc_ext} eq '.sh';
    return 0.8 if $file->{lc_ext} eq '.bat';
    return 0.7 if $file->{execute};
    return 0;
}

sub make_source {
    my ( $class, $raw_source_ref ) = @_;
    my $source = $class->source_class->new($raw_source_ref);

    # TODO: figure out how to pass these over:
    #    $source->source( [ @$exec, @test_args ] );
    #    $source->merge($merge);    # XXX should just be arguments?
}

1;

=head1 AUTHORS

Steve Purkis

=head1 ATTRIBUTION

Originally from L<Test::Harness>?

Moved from L<TAP::Parser>

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector>

=cut
