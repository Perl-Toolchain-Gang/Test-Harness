package TAP::Parser::SourceFactory;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object ();

use Carp qw( confess );
use File::Basename qw( fileparse );

@ISA = qw(TAP::Object);

use constant sources => [];

=head1 NAME

TAP::Parser::SourceFactory - Figures out which Source objects to create from 'raw' sources

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceFactory;
  my $factory = TAP::Parser::SourceFactory->new({ %config });
  my $source  = $factory->make_source( $filename );

=head1 DESCRIPTION

This is a factory class that, given a 'raw' source of TAP, figures out what
type of source it is and creates an appropriate L<TAP::Parser::Source> object.

If you're a plugin author, you'll be interested in how to L</register_source>s,
how L</detect_source> works, and how we L</assemble_meta> data.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

Creates a new factory class:

  my $sf = TAP::Parser::SourceFactory->new( $config );

C<$config> is optional.  If given, sets L</config> and calls L</load_sources>.

=cut

sub _initialize {
    my ( $self, $config ) = @_;
    $self->config( $config || {} )->load_sources;
    return $self;
}

=head3 C<register_source>

Registers a new L<TAP::Parser::Source> with this factory.

  __PACKAGE__->register_source( $source_class );

=cut

sub register_source {
    my ( $class, $dclass ) = @_;

    confess("$dclass must inherit from TAP::Parser::Source!")
      unless UNIVERSAL::isa( $dclass, 'TAP::Parser::Source' );

    my $sources = $class->sources;
    push @{$sources}, $dclass
      unless grep { $_ eq $dclass } @{$sources};

    return $class;
}

##############################################################################

=head2 Instance Methods

=head3 C<config>

 my $cfg = $sf->config;
 $sf->config({ Perl => { %config } });

Chaining getter/setter for the configuration of the available sources.  This is
a hashref keyed on source class whose values contain config to be passed onto
the sources during detection & creation.  Class names may be fully qualified
or abbreviated, eg:

  # these are equivalent
  $sf->sources_config({ 'TAP::Parser::Source::Perl' => { %config } });
  $sf->sources_config({ 'Perl' => { %config } });

=cut

sub config {
    my $self = shift;
    return $self->{config} unless @_;
    unless ( 'HASH' eq ref $_[0] ) {
        $self->_croak('Argument to &config must be a hash reference');
    }
    $self->{config} = shift;
    return $self;
}

sub _config_for {
    my ( $self, $sclass ) = @_;
    my ($abbrv_sclass) = ( $sclass =~ /(?:\:\:)?(\w+)$/ );
    my $config = $self->config->{$abbrv_sclass} || $self->config->{$sclass};
    return $config;
}

##############################################################################

=head3 C<load_sources>

 $sf->load_sources;

Loads the source classes defined in L</config>.  For example, given a config:

  $sf->config({
    MySource => { some => 'config' },
  });

C<load_sources> will attempt to load the C<MySource> class by looking in
C<@INC> for it in this order:

  TAP::Parser::Source::MySource
  MySource

C<croak>s on error.

=cut

sub load_sources {
    my ($self) = @_;
    foreach my $source ( keys %{ $self->config } ) {
        my $sclass = $self->_load_source($source);

        # TODO: store which class we loaded anywhere?
    }
    return $self;
}

sub _load_source {
    my ( $self, $source ) = @_;

    my @errors;
    foreach my $sclass ( "TAP::Parser::Source::$source", $source ) {
        return $sclass if UNIVERSAL::isa( $sclass, 'TAP::Parser::Source' );
        eval "use $sclass";
        if ( my $e = $@ ) {
            push @errors, $e;
            next;
        }
        return $sclass if UNIVERSAL::isa( $sclass, 'TAP::Parser::Source' );
        push @errors, "source '$sclass' is not a TAP::Parser::Source";
    }

    $self->_croak( "Cannot load source '$source': " . join( "\n", @errors ) );
}

##############################################################################

=head3 C<make_source>

Detects and creates a new L<TAP::Parser::Source> for the C<$raw_source_ref>
given (see L</detect_source>).  Dies on error.

=cut

sub make_source {
    my ( $self, $args ) = @_;
    my $raw_source_ref = $args->{raw_source_ref};

    $self->_croak('no raw source ref defined!')
      unless defined $raw_source_ref;
    my $ref_type = ref($raw_source_ref);
    $self->_croak('raw_source_ref is not a reference!') unless $ref_type;

    # is the raw source already an object?
    return $$raw_source_ref
      if ( $ref_type eq 'SCALAR'
        && ref($$raw_source_ref)
        && UNIVERSAL::isa( $$raw_source_ref, 'TAP::Parser::Source' ) );

    # figure out what kind of source it is
    my ( $sd_class, $meta ) = $self->detect_source($raw_source_ref);

    # create it
    my $config = $self->_config_for($sd_class);
    my $source = $sd_class->make_source(
        {   %$args,
            raw_source_ref => $raw_source_ref,
            config         => $config,
            meta           => $meta,
        }
    );

    return $source;
}

=head3 C<detect_source>

Given a reference to the raw source, detects what kind of source it is and
returns I<one> L<TAP::Parser::Source> (the most confident one).  Dies
on error.

The detection algorithm works something like this:

  for (@registered_sources) {
    # ask them how confident they are about handling this source
    $confidence{$source} = $source->can_handle( $source )
  }
  # choose the most confident source

Ties are handled by choosing the first source.

=cut

sub detect_source {
    my ( $self, $raw_source_ref ) = @_;

    confess('no raw source ref defined!') unless defined $raw_source_ref;

    # build up some meta-data about the source so the sources don't have to
    my $meta = $self->assemble_meta($raw_source_ref);

    # find a list of sources that can handle this source:
    my %sources;
    foreach my $dclass ( @{ $self->sources } ) {
        my $config = $self->_config_for($dclass);
        my $confidence
          = $dclass->can_handle( $raw_source_ref, $meta, $config );

        # warn "source: $dclass: $confidence\n";
        $sources{$dclass} = $confidence if $confidence;
    }

    if ( !%sources ) {

        # use Data::Dump qw( pp );
        # warn pp( $meta );

        # error: can't detect source
        my $raw_source_short = substr( $$raw_source_ref, 0, 50 );
        confess("Cannot detect source of '$raw_source_short'!");
        return;
    }

    # if multiple sources can handle it, choose the most confident one
    my @sources = (
        map    {$_}
          sort { $sources{$a} cmp $sources{$b} }
          keys %sources
    );

    # this is really useful for debugging sources:
    if ( $ENV{TAP_HARNESS_SOURCE_FACTORY_VOTES} ) {
        warn(
            "votes: ",
            join( ', ', map {"$_: $sources{$_}"} @sources ),
            "\n"
        );
    }

    # return 1st source
    return pop @sources, $meta;
}

=head3 C<assemble_meta>

Given a reference to the raw source, assembles some meta data about it and
return it as a hashref.  This is done so that the individual sources don't
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
    $meta->{is_object}
      = UNIVERSAL::isa( $raw_source_ref, 'UNIVERSAL' ) ? 1 : 0;

    $meta->{ lc( ref($raw_source_ref) ) } = 1;
    if ( $meta->{scalar} ) {
        my $source = $$raw_source_ref;
        $meta->{length} = length($$raw_source_ref);
        $meta->{has_newlines} = $$raw_source_ref =~ /\n/ ? 1 : 0;

        # only do file checks if it looks like a filename
        if ( !$meta->{has_newlines} and $meta->{length} < 1024 ) {
            my $file = {};
            $file->{exists} = -e $source ? 1 : 0;
            if ( $file->{exists} ) {
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
                $meta->{is_symlink} = $file->{is_symlink}
                  = -l $source ? 1 : 0;
                if ( $file->{symlink} ) {
                    $file->{lstat} = [ lstat(_) ];
                }

                # put together some common info about the file
                ( $file->{basename}, $file->{dir}, $file->{ext} )
                  = map { defined $_ ? $_ : '' }
                  fileparse( $source, qr/\.[^.]*/ );
                $file->{lc_ext} = lc( $file->{ext} );
                $file->{basename} .= $file->{ext} if $file->{ext};

                # TODO: move shebang check from TAP::Parser::SourceFactory
            }
        }
    }
    elsif ( $meta->{array} ) {
        $meta->{size} = $#$raw_source_ref + 1;
    }
    elsif ( $meta->{hash} ) {
        ;    # do nothing
    }

    return $meta;
}

=head3 C<sources>

TODO

=cut

1;

__END__

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head2 Example

If we've done things right, you'll probably want to write a new source,
rather than sub-classing this (see L<TAP::Parser::Source> for that).

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
extensible TAP source detective work by Steve Purkis.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Source>,
L<TAP::Parser::Source>,
L<TAP::Parser::Source::Perl>,
L<TAP::Parser::Source::RawTAP>,
L<TAP::Parser::Source::Executable>

=cut

