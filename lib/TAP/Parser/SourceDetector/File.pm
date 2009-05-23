package TAP::Parser::SourceDetector::File;

use strict;
use vars qw($VERSION @ISA);

use TAP::Parser::SourceFactory  ();
use TAP::Parser::SourceDetector ();
use TAP::Parser::Source::File   ();

@ISA = qw( TAP::Parser::SourceDetector );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::File - Detect raw TAP stored in a file.

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # don't use this directly, use TAP::Parser::SourceFactory !

  # for reference:
  use TAP::Parser::SourceDetector::File;
  my $source;
  if (TAP::Parser::SourceDetector::File->can_handle( \$raw_source )) {
    $source = TAP::Parser::SourceDetector::File->make_source( \$raw_source );
  }

=head1 DESCRIPTION

This is a I<raw TAP stored in a file> L<TAP::Parser::SourceDetector> - it's
job is to figure out if the I<raw> source it's given is a file containing raw
TAP output.  See L<TAP::Parser::SourceFactory> for more details.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=cut

use constant source_class => 'TAP::Parser::Source::File';

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
    my ( $class, $raw_source_ref, $config ) = @_;
    my $source = $class->source_class->new($raw_source_ref);
    return $source;
}

1;

=head1 CONFIGURATION

  {
   extensions => [ @list_of_exts_to_match ]
  }

=head1 AUTHORS

Steve Purkis

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector>

=cut
