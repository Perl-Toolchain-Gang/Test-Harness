package TAP::Parser::SourceDetector::Perl;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceFactory  ();
use TAP::Parser::SourceDetector ();
use TAP::Parser::Source::Perl   ();

use File::Basename qw( fileparse );

@ISA = qw( TAP::Parser::SourceDetector );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::Perl - Perl TAP source detector

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # don't use this directly, use TAP::Parser::SourceFactory !

  # for reference:
  use TAP::Parser::SourceDetector::Perl;
  my $source;
  if (TAP::Parser::SourceDetector::Perl->can_handle( \$raw_source )) {
    $source = TAP::Parser::SourceDetector::Perl->make_source( \$raw_source );
  }

=head1 DESCRIPTION

This is a I<Perl> L<TAP::Parser::SourceDetector> - it's job is to figure out if
the I<raw> source it's given is actually a Perl script.  See
L<TAP::Parser::SourceFactory> for more details.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=cut

use constant source_class => 'TAP::Parser::Source::Perl';

sub can_handle {
    my ( $class, $raw_source_ref, $meta ) = @_;

    return 0 unless $meta->{is_file};
    my $file = $meta->{file};

    return 0.8 if $file->{lc_ext} eq '.t';    # vote higher than Executable
    return 1   if $file->{lc_ext} eq '.pl';

    return 0.75 if $file->{dir} =~ /^t\b/;    # vote higher than Executable

    # TODO: check for shebang, eg: #!.../perl  ?

    # backwards compat, always vote:
    return 0.5;
}

sub make_source {
    my ( $class, $args ) = @_;
    my $raw_source_ref = $args->{raw_source_ref};
    my $perl_script    = $$raw_source_ref;
    my $test_args      = $args->{test_args} || [];

    my $source = $class->source_class->new( $raw_source_ref );
    $source->merge( $args->{merge} );
    $source->switches( $args->{switches} ) if $args->{switches};
    $source->raw_source([ $perl_script, @$test_args ]);

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
