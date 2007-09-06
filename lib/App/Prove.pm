package App::Prove;

use strict;
use TAP::Harness;
use File::Find;
use File::Spec;
use Getopt::Long;
use Carp;

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

BEGIN {
    my @ATTR = qw(
      archive argv blib color directives exec failures
      formatter harness includes lib merge parse quiet really_quiet
      recurse backwards shuffle taint_fail taint_warn verbose
      warnings_fail warnings_warn
    );

    for my $attr (@ATTR) {
        no strict 'refs';
        *{ __PACKAGE__ . '::' . $attr } = sub {
            my $self = shift;
            croak "$attr is read-only" if @_;
            $self->{$attr};
        };
    }

    sub new {
        my $class = shift;
        my $args = shift || {};

        my $self = bless {
            argv              => [],
            includes          => [],
            default_formatter => 'TAP::Harness::Formatter::Basic',
        }, $class;

        for my $attr (@ATTR) {
            if ( exists $args->{$attr} ) {

                # TODO: Some validation here
                $self->{$attr} = $args->{$attr};
            }
        }

        return $self;
    }
}

=head3 C<process_args>

=cut

sub process_args {
    my ( $self, @args ) = @_;

    if ( my @bad = map {"-$_"} grep {/^-(man|help)$/} @args ) {
        die "Long options should be written with two dashes: ",
          join( ', ', @bad ), "\n";
    }

    # Allow cuddling the paths with the -I
    @args = map { /^(-I)(.+)/ ? ( $1, $2 ) : $_ } @args;

    my $help_sub = sub { $self->_help; $self->_exit };

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
            'reverse'     => \$self->{backwards},
            'p|parse'     => \$self->{parse},
            'q|quiet'     => \$self->{quiet},
            'Q|QUIET'     => \$self->{really_quiet},
            'e|exec=s'    => \$self->{exec},
            'm|merge'     => \$self->{merge},
            'I=s@'        => $self->{includes},
            'directives'  => \$self->{directives},
            'h|help|?'    => $help_sub,
            'H|man'       => $help_sub,
            'V|version'   => sub { $self->print_version; $self->_exit },
            'a|archive=s' => \$self->{archive},

            'T' => \$self->{taint_fail},
            't' => \$self->{taint_warn},
            'W' => \$self->{warnings_fail},
            'w' => \$self->{warnings_warn},
        );

        # Stash the remainder of argv for later
        $self->{argv} = [@ARGV];
    }
}

sub _exit { exit( $_[1] || 0 ) }

sub _help {
    my $self = shift;

    eval('use Pod::Usage 1.12 ()');
    my $err = $@;

    # XXX Getopt::Long is being helpy
    local $SIG{__DIE__} = sub { warn @_; $self->_exit; };
    if ($err) {
        die 'Please install Pod::Usage for the --help option '
          . '(or try `perldoc prove`.)'
          . "\n ($@)";
    }

    Pod::Usage::pod2usage( { -verbose => 1 } );
}

sub _color_default {
    my $self = shift;

    return -t STDOUT
      && !( $^O =~ /MSWin32/ );
}

sub _get_args {
    my $self          = shift;
    my $harness_class = 'TAP::Harness';
    my %args;

    if ( defined $self->color ? $self->color : $self->_color_default ) {
        require TAP::Harness::Color;
        $harness_class = 'TAP::Harness::Color';
    }

    if ( $self->archive ) {
        eval { require TAP::Harness::Archive };
        die
          "TAP::Harness::Archive is required to use the --archive feature: $@"
          if $@;
        $harness_class = 'TAP::Harness::Archive';
        $args{archive} = $self->archive;
    }

    if ( $self->harness ) {
        $harness_class = $self->harness;
        eval "use $harness_class";
        die "Cannot use harness ($harness_class): $@" if $@;
    }

    my $formatter_class;
    if ( $self->formatter ) {
        $formatter_class = $self->formatter;
        eval "use $formatter_class";
        die "Cannot use formatter ($formatter_class): $@" if $@;
    }

    unless ($formatter_class) {
        my $class = $self->{default_formatter};
        eval "use $class";
        $formatter_class = $class unless $@;
    }

    if ( $self->taint_fail && $self->taint_warn ) {
        die "-t and -T are mutually exclusive";
    }

    if ( $self->warnings_fail && $self->warnings_warn ) {
        die "-w and -W are mutually exclusive";
    }

    for my $a (qw( lib switches )) {
        my $method = "_get_$a";
        my $val    = $self->$method();
        $args{$a} = $val if defined $val;
    }

    $args{merge}    = $self->merge    if $self->merge;
    $args{verbose}  = $self->verbose  if $self->verbose;
    $args{failures} = $self->failures if $self->failures;

    $args{quiet}        = 1 if $self->quiet;
    $args{really_quiet} = 1 if $self->really_quiet;
    $args{errors}       = 1 if $self->parse;

    $args{exec} = length( $self->exec ) ? [ split( / /, $self->exec ) ] : []
      if ( defined( $self->exec ) );

    $args{directives} = 1 if $self->directives;

    if ($formatter_class) {
        $args{formatter} = $formatter_class->new;
    }

    return ( \%args, $harness_class );
}

=head3 C<run>

=cut

sub run {
    my $self = shift;

    my @tests = $self->_get_tests( @{ $self->argv } );

    $self->_shuffle(@tests) if $self->shuffle;
    @tests = reverse @tests if $self->backwards;

    $self->_runtests( $self->_get_args, @tests );
}

sub _runtests {
    my ( $self, $args, $harness_class, @tests ) = @_;
    my $harness    = $harness_class->new($args);
    my $aggregator = $harness->runtests(@tests);

    $self->_exit( $aggregator->has_problems ? 1 : 0 );
}

sub _get_switches {
    my $self = shift;
    my @switches;

    # notes that -T or -t must be at the front of the switches!
    if ( $self->taint_fail ) {
        push @switches, 'T';
    }
    elsif ( $self->taint_warn ) {
        push @switches, 't';
    }
    if ( $self->warnings_fail ) {
        push @switches, 'W';
    }
    elsif ( $self->warnings_warn ) {
        push @switches, 'w';
    }

    return @switches ? \@switches : ();
}

sub _get_lib {
    my $self = shift;
    my @libs;
    if ( $self->lib ) {
        push @libs, 'lib';
    }
    if ( $self->blib ) {
        push @libs, 'blib/lib';
    }
    if ( @{ $self->includes } ) {
        push @libs, @{ $self->includes };
    }

    # Huh?
    return @libs ? \@libs : ();
}

sub _get_tests {
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
            my @files = $self->_expand_dir($arg);
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

sub _expand_dir {
    my $self = shift;
    my $dir  = shift;
    my @tests;
    if ( $self->recurse ) {
        find(
            sub { -f && /\.t$/ && push @tests => $File::Find::name },
            $dir
        );
    }
    else {
        @tests = glob( File::Spec->catfile( $dir, '*.t' ) );
    }
    return sort @tests;
}

sub _shuffle {
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

=head2 Attributes

=over

=item C< archive >

=item C< argv >

=item C< backwards >

=item C< blib >

=item C< color >

=item C< directives >

=item C< exec >

=item C< failures >

=item C< formatter >

=item C< harness >

=item C< includes >

=item C< lib >

=item C< merge >

=item C< parse >

=item C< quiet >

=item C< really_quiet >

=item C< recurse >

=item C< shuffle >

=item C< taint_fail >

=item C< taint_warn >

=item C< verbose >

=item C< warnings_fail >

=item C< warnings_warn >

=back

# vim:ts=4:sw=4:et:sta
