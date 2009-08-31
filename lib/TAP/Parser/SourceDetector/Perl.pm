package TAP::Parser::SourceDetector::Perl;

use strict;
use Config;
use vars qw($VERSION @ISA);

use constant IS_WIN32 => ( $^O =~ /^(MS)?Win32$/ );
use constant IS_VMS   => ( $^O eq 'VMS' );

use TAP::Parser::SourceDetector::Executable ();
use TAP::Parser::SourceFactory              ();
use TAP::Parser::Iterator::Process          ();
use TAP::Parser::Utils qw( split_shell );

@ISA = 'TAP::Parser::SourceDetector::Executable';

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

=head1 NAME

TAP::Parser::SourceDetector::Perl - Stream TAP from a Perl executable

=head1 VERSION

Version 3.18

=cut

$VERSION = '3.18';

=head1 SYNOPSIS

  use TAP::Parser::SourceDetector::Perl;
  my $class = 'TAP::Parser::SourceDetector::Perl'
  my $vote  = $class->can_handle( $source );
  my $iter  = $class->make_iterator( $source );

=head1 DESCRIPTION

This is a I<Perl> L<TAP::Parser::SourceDetector> - it has 2 jobs:

1. Figure out if the L<TAP::Parser::Source> it's given is actually a Perl
script.  See L</can_handle> for more details.

2. Takes a Perl script and creates an iterator from it.

Unless you're writing a plugin or subclassing L<TAP::Parser>, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=cut

sub _initialize {
    my ( $self, @args ) = @_;
    $self->SUPER::_initialize(@args);
    $self->{switches} = [];
    return $self;
}


=head3 C<can_handle>

  my $vote = $class->can_handle( $source );

Only votes if $source looks like a file.  Casts the following votes:

  0.99 if it has a shebang ala "#!...perl"
  0.8  if it's a .t file
  1.0  if it's a .pl file
  0.75 if it's in a 't' directory
  0.5  by default (backwards compat)

=cut

sub can_handle {
    my ( $class, $source ) = @_;
    my $meta = $source->meta;

    return 0 unless $meta->{is_file};
    my $file = $meta->{file};

    if (my $shebang = $file->{shebang}) {
	return 0.99 if $shebang =~ /^#!.*\bperl/;
    }

    return 0.8 if $file->{lc_ext} eq '.t';    # vote higher than Executable
    return 1   if $file->{lc_ext} eq '.pl';

    return 0.75 if $file->{dir} =~ /^t\b/;    # vote higher than Executable

    # backwards compat, always vote:
    return 0.5;
}

=head3 C<make_iterator>

  my $iterator = $class->make_iterator( $source );

Constructs & returns a new L<TAP::Parser::Iterator::Process> for the source.
Assumes C<$source-E<gt>raw> contains a reference to the perl script.  C<croak>s
if the file could not be found.

The command to run is built as follows:

  $perl @switches $perl_script @test_args

The perl command to use is determined by L</get_perl>.  The command generated
is guaranteed to preserve:

  PERL5LIB
  PERL5OPT
  Taint Mode, if set in the script's shebang

I<Note:> the command generated will I<not> respect any shebang line defined in
your Perl script.  This is only a problem if you have compiled a custom version
of Perl or if you want to use a specific version of Perl for one test and a
different version for another, for example:

  #!/path/to/a/custom_perl --some --args
  #!/usr/local/perl-5.6/bin/perl -w

Currently you need to write a plugin to get around this.

=cut

sub make_iterator {
    my ( $class, $source ) = @_;
    my $meta = $source->meta;
    my $perl_script = ${ $source->raw };

    $class->_croak("Cannot find ($perl_script)") unless $meta->{is_file};

    # TODO: does this really need to be done here?
    $class->_autoflush( \*STDOUT );
    $class->_autoflush( \*STDERR );

    my @switches = $class->_switches( $source );
    my $path_sep = $Config{path_sep};
    my $path_re  = qr{$path_sep};

    # Filter out any -I switches to be handled as libs later.
    #
    # Nasty kludge. It might be nicer if we got the libs separately
    # although at least this way we find any -I switches that were
    # supplied other then as explicit libs.
    #
    # We filter out any names containing colons because they will break
    # PERL5LIB
    my @libs;
    my @filtered_switches;
    for (@switches) {
        if ( !/$path_re/ && / ^ ['"]? -I ['"]? (.*?) ['"]? $ /x ) {
            push @libs, $1;
        }
        else {
            push @filtered_switches, $_;
        }
    }
    @switches = @filtered_switches;

    my $setup = sub {
        if (@libs) {
            $ENV{PERL5LIB}
              = join( $path_sep, grep {defined} @libs, $ENV{PERL5LIB} );
        }
    };

    # Cargo culted from comments seen elsewhere about VMS / environment
    # variables. I don't know if this is actually necessary.
    my $previous = $ENV{PERL5LIB};
    my $teardown = sub {
        if ( defined $previous ) {
            $ENV{PERL5LIB} = $previous;
        }
        else {
            delete $ENV{PERL5LIB};
        }
    };

    # Taint mode ignores environment variables so we must retranslate
    # PERL5LIB as -I switches and place PERL5OPT on the command line
    # in order that it be seen.
    if ( grep { $_ eq "-T" || $_ eq "-t" } @switches ) {
        push @switches, $class->_libs2switches( @libs );
        push @switches, split_shell( $ENV{PERL5OPT} );
    }

    my @command = $class->_get_command_for_switches($source, @switches)
      or $class->_croak("No command found!");

    return TAP::Parser::Iterator::Process->new(
        {   command  => \@command,
            merge    => $source->merge,
            setup    => $setup,
            teardown => $teardown,
        }
    );
}

sub _get_command_for_switches {
    my ($class, $source, @switches) = @_;
    my $file = ${ $source->raw };
    my @args = @{ $source->test_args || [] };
    my $command = $class->get_perl;

    # XXX don't need to quote if we treat the parts as atoms (except maybe vms)
    #$file = qq["$file"] if ( $file =~ /\s/ ) && ( $file !~ /^".*"$/ );
    my @command = ( $command, @switches, $file, @args );
    return @command;
}

sub _libs2switches {
    my $class = shift;
    return map {"-I$_"} grep {$_} @_;
}


=head3 C<get_taint>

Decode any taint switches from a Perl shebang line.

  # $taint will be 't'
  my $taint = TAP::Parser::SourceDetector::Perl->get_taint( '#!/usr/bin/perl -t' );

  # $untaint will be undefined
  my $untaint = TAP::Parser::SourceDetector::Perl->get_taint( '#!/usr/bin/perl' );

=cut

sub get_taint {
    my ( $class, $shebang ) = @_;
    return
      unless defined $shebang
          && $shebang =~ /^#!.*\bperl.*\s-\w*([Tt]+)/;
    return $1;
}

sub _switches {
    my ($class, $source) = @_;
    my $file = ${ $source->raw };
    my @args = @{ $source->test_args || [] };
    my @switches = @{ $source->switches || [] };
    my $shebang  = $source->meta->{file}->{shebang};
    return unless defined $shebang;

    my $taint = $class->get_taint( $shebang );
    push @switches, "-$taint" if defined $taint;

    # Quote the argument if we're VMS, since VMS will downcase anything
    # not quoted.
    if (IS_VMS) {
        for (@switches) {
            $_ = qq["$_"];
        }
    }

    return @switches;
}


=head3 C<get_perl>

Gets the version of Perl currently running the test suite.

=cut

sub get_perl {
    my $class = shift;
    return $ENV{HARNESS_PERL} if defined $ENV{HARNESS_PERL};
    return Win32::GetShortPathName($^X) if IS_WIN32;
    return $^X;
}

1;

__END__

=head1 SUBCLASSING

Please see L<TAP::Parser/SUBCLASSING> for a subclassing overview.

=head2 Example

  package MyPerlSourceDetector;

  use strict;
  use vars '@ISA';

  use TAP::Parser::SourceDetector::Perl;

  @ISA = qw( TAP::Parser::SourceDetector::Perl );

  # use the version of perl from the shebang line in the test file
  sub get_perl {
      my $self = shift;
      if (my $shebang = $self->shebang( $self->{file} )) {
          $shebang =~ /^#!(.*\bperl.*?)(?:(?:\s)|(?:$))/;
	  return $1 if $1;
      }
      return $self->SUPER::get_perl(@_);
  }

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::SourceFactory>,
L<TAP::Parser::SourceDetector>,
L<TAP::Parser::SourceDetector::Executable>,
L<TAP::Parser::SourceDetector::File>,
L<TAP::Parser::SourceDetector::Handle>,
L<TAP::Parser::SourceDetector::RawTAP>

=cut
