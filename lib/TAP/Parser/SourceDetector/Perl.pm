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
    my ( $class, $raw_source_ref ) = @_;

    return 0 unless defined $$raw_source_ref;
    return 0 if $$raw_source_ref =~ /\n/;

    my $source = $$raw_source_ref;
    return 0 unless -f $source;

    my ( $name, $path, $ext ) = fileparse($source);
    if ($ext) {
        $ext = lc($ext);
        return 0.8 if $ext eq 't';    # more than Executable
        return 1   if $ext eq 'pl';
    }

    if ($path) {
        return 0.75 if $path =~ /^t\b/;    # more than Executable
    }

    # TODO: check for shebang, eg: #!.../perl  ?

    return 0.5;
}

sub make_source {
    my ( $class, $raw_source_ref ) = @_;
    my $source = $class->source_class->new($raw_source_ref);

    # TODO: figure out how to pass these over:
    #    $perl->switches($switches) if $switches;
    #    $perl->merge($merge);    # XXX args to new()?
    #    $perl->source( [ $source, @test_args ] );
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
