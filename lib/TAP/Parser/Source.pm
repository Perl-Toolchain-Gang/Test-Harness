package TAP::Parser::Source;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object ();
use File::Basename qw( fileparse );

@ISA = qw(TAP::Object);

=head1 NAME

TAP::Parser::Source - a TAP source & meta data about it

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  # TODO

=head1 DESCRIPTION

This is a data object used by L<TAP::Parser::SourceFactory> to pass a TAP
I<source> and meta data about it to L<TAP::Parser::SourceDetector>s.

Unless you're writing a new L<TAP::Parser::SourceDetector>, a plugin or
subclassing L<TAP::Parser>, you probably won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $source = TAP::Parser::Source->new;

Returns a new C<TAP::Parser::Source> object.

=cut

# new() implementation supplied by TAP::Object

sub _initialize {
    my ($self) = @_;
    $self->meta( {} );
    $self->config( {} );
    return $self;
}


##############################################################################

=head2 Instance Methods

=head3 C<raw>

  my $raw = $source->raw;
  $source->raw( $some_value );

Chaining getter/setter for the raw TAP source.

=head3 C<meta>

  my $meta = $source->meta;
  $source->meta({ %some_value });

Chaining getter/setter for meta data about the source.  This defaults to an
empty hashref.

=head3 C<config>

  my $config = $source->config;
  $source->config({ %some_value });

Chaining getter/setter for the source's configuration, if any.  This defaults
to an empty hashref.

=head3 C<merge>

  my $merge = $source->merge;
  $source->config( $bool );

Chaining getter/setter for the flag that dictates whether STDOUT and STDERR
should be merged (where appropriate).  Defaults to undef.

=head3 C<switches>

  my $switches = $source->switches;
  $source->config([ @switches ]);

Chaining getter/setter for the list of command-line switches that should be
passed to the source (where appropriate).  Defaults to undef.

=head3 C<test_args>

  my $test_args = $source->test_args;
  $source->config([ @test_args ]);

Chaining getter/setter for the list of command-line arguments that should be
passed to the source (where appropriate).  Defaults to undef.

=cut

sub raw {
    my $self = shift;
    return $self->{raw} unless @_;
    $self->{raw} = shift;
    return $self;
}

sub meta {
    my $self = shift;
    return $self->{meta} unless @_;
    $self->{meta} = shift;
    return $self;
}

sub has_meta {
    return scalar %{ shift->meta } ? 1 : 0;
}

sub config {
    my $self = shift;
    return $self->{config} unless @_;
    $self->{config} = shift;
    return $self;
}

sub merge {
    my $self = shift;
    return $self->{merge} unless @_;
    $self->{merge} = shift;
    return $self;
}

sub switches {
    my $self = shift;
    return $self->{switches} unless @_;
    $self->{switches} = shift;
    return $self;
}

sub test_args {
    my $self = shift;
    return $self->{test_args} unless @_;
    $self->{test_args} = shift;
    return $self;
}


=head3 C<assemble_meta>

  my $meta = $source->assemble_meta;

Gathers meta data about the L</raw> source, stashes it in L</meta> and returns
it as a hashref.  This is done so that the L<TAP::Parser::SourceDetector>s don't
have to repeat common checks.  Currently this includes:

    is_scalar => $bool,
    is_hash   => $bool,
    is_array  => $bool,

    # for scalars:
    length => $n
    has_newlines => $bool

    # only done if the scalar looks like a filename
    is_file => $bool,
    is_dir  => $bool,
    is_symlink => $bool,
    file => {
        # only done if the scalar looks like a filename
        basename => $string, # including ext
        dir      => $string,
        ext      => $string,
        lc_ext   => $string,
        # system checks
        exists  => $bool,
        stat    => [ ... ], # perldoc -f stat
        empty   => $bool,
        size    => $n,
        text    => $bool,
        binary  => $bool,
        read    => $bool,
        write   => $bool,
        execute => $bool,
        setuid  => $bool,
        setgid  => $bool,
        sticky  => $bool,
        is_file => $bool,
        is_dir  => $bool,
        is_symlink => $bool,
        # only done if the file's a symlink
        lstat      => [ ... ], # perldoc -f lstat
        # only done if the file's a readable text file
        shebang => $first_line,
    }

  # for arrays:
  size => $n,

=cut

sub assemble_meta {
    my ($self) = @_;

    return $self->meta if $self->has_meta;

    my $meta   = $self->meta;
    my $raw = $self->raw;

    # rudimentary is object test - if it's blessed it'll
    # inherit from UNIVERSAL
    $meta->{is_object}
      = UNIVERSAL::isa( $raw, 'UNIVERSAL' ) ? 1 : 0;

    if ($meta->{is_object}) {
	$meta->{class} = ref( $raw );
    } else {
	my $ref = lc( ref($raw) );
	$meta->{"is_$ref"} = 1;
    }

    if ( $meta->{is_scalar} ) {
        my $source = $$raw;
        $meta->{length} = length($$raw);
        $meta->{has_newlines} = $$raw =~ /\n/ ? 1 : 0;

        # only do file checks if it looks like a filename
        if ( !$meta->{has_newlines} and $meta->{length} < 1024 ) {
            my $file = {};
            $file->{exists} = -e $source ? 1 : 0;
            if ( $file->{exists} ) {
                $meta->{file} = $file;

                # avoid extra system calls (see `perldoc -f -X`)
                $file->{stat}    = [ stat(_) ];
                $file->{empty}   = -z _ ? 1 : 0;
                $file->{size}    = -s _;
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
                if ( $file->{is_symlink} ) {
                    $file->{lstat} = [ lstat(_) ];
                }

                # put together some common info about the file
                ( $file->{basename}, $file->{dir}, $file->{ext} )
                  = map { defined $_ ? $_ : '' }
		    fileparse( $source, qr/\.[^.]*/ );
                $file->{lc_ext} = lc( $file->{ext} );
                $file->{basename} .= $file->{ext} if $file->{ext};

		if ( $file->{text} and $file->{read} ) {
		    eval {
			$file->{shebang} = $self->_read_shebang( $$raw );
		    };
		    if (my $e = $@) {
			warn $e;
		    }
		}
            }
        }
    }
    elsif ( $meta->{is_array} ) {
        $meta->{size} = $#$raw + 1;
    }
    elsif ( $meta->{is_hash} ) {
        ;    # do nothing
    }

    return $meta;
}

sub _read_shebang {
    my ($self, $file) = @_;
    my $shebang;
    local *TEST;
    if ( open( TEST, $file ) ) {
	$shebang = <TEST>;
	chomp $shebang;
	close(TEST) or die "Can't close $file. $!\n";
    } else {
	die "Can't open $file. $!\n";
    }
    return $shebang;
}

1;

__END__

=head1 AUTHORS

Steve Purkis.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector>

=cut

