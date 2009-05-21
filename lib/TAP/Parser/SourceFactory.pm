package TAP::Parser::SourceFactory;

use strict;
use vars qw($VERSION @ISA %DETECTORS);

use TAP::Object ();

use Carp qw( confess );
use File::Basename qw( fileparse );

@ISA = qw(TAP::Object);

use constant detectors => [];

=head1 NAME

TAP::Parser::SourceFactory - Internal TAP::Parser Source

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceFactory;
  my $factory = TAP::Parser::SourceFactory->new;
  my $source  = $factory->make_source( $filename );

=head1 DESCRIPTION

This is a factory class for different types of TAP sources.  If you're reading
this, you're likely either a plugin author who will be interested in how to
L</register_detector>s, or you're just interested in how a TAP source's type
is determined (see L</detect_source>);

=head1 METHODS

=head2 Class Methods

=head3 C<new>

Creates a new factory class.

=cut

sub _initialize {
    my ( $self, @args ) = @_;

    # initialize your object
    return $self;
}

=head3 C<register_detector>

Registers a new L<TAP::Parser::SourceDetector> with this factory.

  __PACKAGE__->register_detector( $detector_class );

=cut

# either 'registry' approach, or scan @INC & load plugins.
# was thinking 'detectors' ala:
# TAP::Parser::SourceDetector::Archive, etc...
sub register_detector {
    my ( $class, $dclass ) = @_;

    confess("$dclass must inherit from TAP::Parser::SourceDetector!")
      unless UNIVERSAL::isa( $dclass, 'TAP::Parser::SourceDetector' );

    my $detectors = $class->detectors;
    push @{$detectors}, $dclass
      unless grep { $_ eq $dclass } @{$detectors};

    return $class;
}

=head2 Instance Methods

=head3 C<make_source>

Detects and creates a new L<TAP::Parser::Source> for the C<$raw_source_ref>
given (see L</detect_source>).  Dies on error.

=cut

sub make_source {
    my ( $self, $raw_source_ref ) = @_;

    confess('no raw source ref defined!') unless defined $raw_source_ref;
    my $ref_type = ref( $raw_source_ref );
    confess('raw_source_ref is not a reference!') unless $ref_type;

    # is the raw source already an object?
    return $$raw_source_ref
      if ( $ref_type eq 'SCALAR' && ref($$raw_source_ref)
        && UNIVERSAL::isa( $$raw_source_ref, 'TAP::Parser::Source' ) );

    # figure out what kind of source it is
    my $source_detector = $self->detect_source($raw_source_ref);
    my $source          = $source_detector->make_source($raw_source_ref);

    return $source;
}

=head3 C<detect_source>

Given a reference to the raw source, detects what kind of source it is and
returns I<one> L<TAP::Parser::SourceDetector> (the most confident one).  Dies
on error.

The detection algorithm works something like this:

  for all registered detectors
    ask them how confident they are about handling this source
  choose the most confident detector

Ties are handled by choosing the first detector.

=cut

sub detect_source {
    my ( $self, $raw_source_ref ) = @_;

    confess('no raw source ref defined!') unless defined $raw_source_ref;

    # build up some meta-data about the source so the detectors don't have to
    my $meta = $self->assemble_meta( $raw_source_ref );

    # find a list of detectors that can handle this source:
    my %detectors;
    foreach my $dclass ( @{ $self->detectors } ) {
        my $confidence = $dclass->can_handle($raw_source_ref, $meta);
        $detectors{$dclass} = $confidence if $confidence;
    }

    if ( !%detectors ) {
	# use Data::Dump qw( pp );
	# warn pp( $meta );

        # error: can't detect source
        my $raw_source_short = substr( $$raw_source_ref, 0, 50 );
        confess("Couldn't detect source of '$raw_source_short'!");
        return;
    }

    # if multiple detectors can handle it, choose the most confident one
    my @detectors = (
        map    {$_}
          sort { $detectors{$a} cmp $detectors{$b} }
          keys %detectors
    );

    # warn "votes: " . join( ', ', map { "$_: $detectors{$_}" } @detectors ) . "\n";

    # return 1st detector
    return pop @detectors;
}


=head3 C<assemble_meta>

Given a reference to the raw source, assembles some meta data about it and
return it as a hashref.  This is done so that the individual detectors don't
have to repeat common tests.  Currently this includes:

  {
   TODO
  }

=cut

sub assemble_meta {
    my ( $self, $raw_source_ref ) = @_;
    my $meta = {};

    # rudimentary is object test - if it's blessed it'll
    # inherit from UNIVERSAL
    $meta->{is_object} = UNIVERSAL::isa( $raw_source_ref, 'UNIVERSAL' ) ? 1 : 0;

    $meta->{lc( ref( $raw_source_ref ) )} = 1;
    if ($meta->{scalar}) {
	my $source = $$raw_source_ref;
	$meta->{length} = length( $$raw_source_ref );
	$meta->{has_newlines} = $$raw_source_ref =~ /\n/ ? 1 : 0;

	# only do file checks if it looks like a filename
	if (! $meta->{has_newlines} and $meta->{length} < 1024) {
	    my $file = {};
	    $file->{exists} = -e $source ? 1 : 0;
	    if ($file->{exists}) {
		$meta->{file} = $file;

		# avoid extra system calls (see `perldoc -f -X`)
		$file->{stat}    = [ stat(_) ];
		$file->{empty}   = -z _ ? 1 : 0;
		$file->{size}    = -s _ ? 1 : 0;
		$file->{text}    = -T _ ? 1 : 0;
		$file->{binary}  = -B _ ? 1 : 0;
		$file->{read}    = -r _ ? 1 : 0;
		$file->{write}   = -w _ ? 1 : 0;
		$file->{execute} = -x _ ? 1 : 0;
		$file->{setuid}  = -u _ ? 1 : 0;
		$file->{setgid}  = -g _ ? 1 : 0;
		$file->{sticky}  = -k _ ? 1 : 0;

		$meta->{is_file} = $file->{is_file} = -f _ ? 1 : 0;
		$meta->{is_dir}  = $file->{is_dir}  = -d _ ? 1 : 0;

		# symlink check requires another system call
		$meta->{is_symlink} = $file->{is_symlink} = -l $source ? 1 : 0;
		if ($file->{symlink}) {
		    $file->{lstat}  = [ lstat(_) ];
		}

		# put together some common info about the file
		( $file->{basename}, $file->{dir}, $file->{ext} )
		  = map { defined $_ ? $_ : '' }
		    fileparse( $source, qr/\.[^.]*/ );
		$file->{lc_ext}    = lc( $file->{ext} );
		$file->{basename} .= $file->{ext} if $file->{ext};
	    }
	}
    } elsif ($meta->{array}) {
	$meta->{size} = $#$raw_source_ref + 1;
    } elsif ($meta->{hash}) {
	; # do nothing
    }

    return $meta;
}

1;

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head2 Example

If I've done things right, you'll probably want to write a new detector,
rather than sub-classing this (see L<TAP::Parser::SourceDetector> for that).

But in case you find the need to...

  package MySourceFactory;

  use strict;
  use vars '@ISA';

  use TAP::Parser::SourceFactory;

  @ISA = qw( TAP::Parser::SourceFactory );

  # override source detection algorithm
  sub detect_source {
    my ($self, $raw_source_ref, $meta) = @_;
    # do detective work, using $meta and whatever else...
  }

  1;

=head1 AUTHORS

Steve Purkis

=head1 ATTRIBUTION

Originally ripped off from L<Test::Harness>.

Moved out of L<TAP::Parser> & converted to a factory class to support
extensible TAP source detective work.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::Perl>,
L<TAP::Parser::SourceDetector::RawTAP>,
L<TAP::Parser::SourceDetector::Executable>

=cut

