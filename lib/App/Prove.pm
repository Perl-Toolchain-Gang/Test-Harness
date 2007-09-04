package App::Prove;

use strict;
use TAP::Harness;
use File::Find;
use File::Spec;
use Getopt::Long;

use vars qw($VERSION);

=head1 NAME

App::Prove - the guts of the C<prove> command.

=head1 VERSION

Version 2.99_02

=cut

$VERSION = '2.99_02';

=head1 METHODS

=head2 Class Methods

=head3 C<new>

=cut

sub new {
    my $class = shift;
    my $args = shift || {};

    my $opts = delete $args->{options} || \@ARGV;

    my $self = bless {
        includes          => [],
        default_formatter => 'TAP::Harness::Formatter::Basic',
    }, $class;

    # Allow cuddling the paths with the -I
    my @args = map { /^(-I)(.+)/ ? ( $1, $2 ) : $_ } @$opts;
    my $color_default = -t STDOUT && !( $^O =~ /MSWin32/ );

    my $help_sub = sub {
        eval('use Pod::Usage 1.12 ()');
        my $err = $@;

        # XXX Getopt::Long is being helpy
        local $SIG{__DIE__} = sub { warn @_; exit; };
        if ($err) {
            die 'Please install Pod::Usage for the --help option '
              . '(or try `perldoc prove`.)'
              . "\n ($@)";
        }

        Pod::Usage::pod2usage( { -verbose => 1 } );
        exit;
    };

    if ( my @bad = map {"-$_"} grep {/^-(man|help)$/} @args ) {
        die "Long options should be written with two dashes: ",
          join( ', ', @bad ), "\n";
    }

    {
        local @ARGV = @args;
        Getopt::Long::Configure( 'no_ignore_case', 'bundling' );
        GetOptions(
            'v|verbose'   => \$self->{verbose},
            'f|failures'  => \$self->{failures},
            'l|lib'       => \$self->{lib},
            'b|blib'      => \$self->{blib},
            's|shuffle'   => \$self->{shuffle},
            'color!'      => \$self->{color},
            'c'           => \$self->{color},
            'harness=s'   => \$self->{harness},
            'formatter=s' => \$self->{formatter},
            'r|recurse'   => \$self->{recurse},
            'reverse'     => \$self->{reverse},
            'p|parse'     => \$self->{parse},
            'q|quiet'     => \$self->{quiet},
            'Q|QUIET'     => \$self->{really_quiet},
            'e|exec=s'    => \$self->{exec},
            'm|merge'     => \$self->{merge},
            'I=s@'        => \$self->{includes},
            'directives'  => \$self->{directives},
            'h|help|?'    => $help_sub,
            'H|man'       => $help_sub,
            'V|version'   => sub { $self->print_version(); exit },
            'a|archive=s' => \$self->{archive},

            #'x|xtension=s' => \$self->{extension},
            'T' => \$self->{taint_fail},
            't' => \$self->{taint_warn},
            'W' => \$self->{warnings_fail},
            'w' => \$self->{warnings_warn},
        );

        # Stash the remainder of argv for later
        $self->{argv} = [@ARGV];
    }

    if ( !defined $self->{color} ) {
        $self->{color} = $color_default;
    }

# XXX otherwise, diagnostics and failure messages are out of sequence
# or we can't suppress STDERR on quiet
#$self->{merge} = 1 if $self->{failures} || $self->{quiet} || $self->{really_quiet};

    return $self;
}

=head3 C<run>

=cut

sub run {
    my $self = shift;

    my $harness_class = 'TAP::Harness';
    my %args;

    if ( $self->{color} ) {
        require TAP::Harness::Color;
        $harness_class = 'TAP::Harness::Color';
    }

    if ( $self->{archive} ) {
        eval { require TAP::Harness::Archive };
        die
          "TAP::Harness::Archive is required to use the --archive feature: $@"
          if $@;
        $harness_class = 'TAP::Harness::Archive';
        $args{archive} = $self->{archive};
    }

    if ( $self->{harness} ) {
        eval "use $self->{harness}";
        die "Cannot use harness ($self->{harness}): $@" if $@;
        $harness_class = $self->{harness};
    }

    my $formatter_class;
    if ( $self->{formatter} ) {
        eval "use $self->{formatter}";
        die "Cannot use formatter ($self->{formatter}): $@" if $@;
        $formatter_class = $self->{formatter};
    }

    unless ($formatter_class) {
        eval "use $self->{default_formatter}";
        $formatter_class = $self->{default_formatter} unless $@;
    }

    my @tests = $self->get_tests( @{ $self->{argv} } );

    $self->shuffle(@tests) if $self->{shuffle};
    @tests = reverse @tests if $self->{reverse};

    if ( $self->{taint_fail} && $self->{taint_warn} ) {
        die "-t and -T are mutually exclusive";
    }
    if ( $self->{warnings_fail} && $self->{warnings_warn} ) {
        die "-w and -W are mutually exclusive";
    }

    $args{lib}          = $self->get_libs;
    $args{switches}     = $self->get_switches;
    $args{merge}        = $self->{merge} if $self->{merge};
    $args{verbose}      = $self->{verbose} if $self->{verbose};
    $args{failures}     = $self->{failures} if $self->{failures};
    $args{quiet}        = 1 if $self->{quiet};
    $args{really_quiet} = 1 if $self->{really_quiet};
    $args{errors}       = 1 if $self->{parse};
    $args{exec}
      = length( $self->{exec} ) ? [ split( / /, $self->{exec} ) ] : []
      if ( defined( $self->{exec} ) );

    $args{directives} = 1 if $self->{directives};

    if ($formatter_class) {
        $args{formatter} = $formatter_class->new;
    }

    my $harness    = $harness_class->new( \%args );
    my $aggregator = $harness->runtests(@tests);

    exit $aggregator->has_problems ? 1 : 0;
}

=head3 C<get_switches>

=cut

sub get_switches {
    my $self = shift;
    my @switches;

    # notes that -T or -t must be at the front of the switches!
    if ( $self->{taint_fail} ) {
        push @switches, 'T';
    }
    elsif ( $self->{taint_warn} ) {
        push @switches, 't';
    }
    if ( $self->{warnings_fail} ) {
        push @switches, 'W';
    }
    elsif ( $self->{warnings_warn} ) {
        push @switches, 'w';
    }

    return @switches ? \@switches : ();
}

=head3 C<get_libs>

=cut

sub get_libs {
    my $self = shift;
    my @libs;
    if ( $self->{lib} ) {
        push @libs, 'lib';
    }
    if ( $self->{blib} ) {
        push @libs, 'blib/lib';
    }
    if ( @{ $self->{includes} } ) {
        push @libs, @{ $self->{includes} };
    }
    return @libs ? \@libs : ();
}

=head3 C<get_tests>

=cut

sub get_tests {
    my $self = shift;
    my @argv = @_;
    my ( @tests, %tests );
    @argv = 't' unless @argv;
    foreach my $arg (@argv) {
        if ( '-' eq $arg ) {
            push @argv => <STDIN>;
            chomp(@argv);
            next;
        }

        if ( -d $arg ) {
            my @files = $self->_get_tests($arg);
            foreach my $file (@files) {
                push @tests => $file unless exists $tests{$file};
            }
            @tests{@files} = (1) x @files;
        }
        else {
            push @tests => $arg unless exists $tests{$arg};
            $tests{$arg} = 1;
        }
    }
    return @tests;
}

sub _get_tests {
    my $self = shift;
    my $dir  = shift;
    my @tests;
    if ( $self->{recurse} ) {
        find(
            sub { -f && /\.t$/ && push @tests => $File::Find::name },
            $dir
        );
    }
    else {
        @tests = glob( File::Spec->catfile( $dir, '*.t' ) );
    }
    return @tests;
}

=head3 C<shuffle>

=cut

sub shuffle {
    my $self = shift;

    # Fisher-Yates shuffle
    my $i = @_;
    while ($i) {
        my $j = rand $i--;
        @_[ $i, $j ] = @_[ $j, $i ];
    }
}

=head3 C<print_version>

=cut

sub print_version {
    my $self = shift;
    printf(
        "TAP::Harness v%s and Perl v%vd\n",
        $Tap::Harness::VERSION, $^V
    );
}

1;

__END__

# vim:ts=4:sw=4:et:sta
