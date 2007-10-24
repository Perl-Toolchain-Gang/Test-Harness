package App::Prove;

use strict;
use TAP::Harness;
use File::Find;
use File::Spec;
use Getopt::Long;
use Carp;

use vars qw($VERSION);

=head1 NAME

App::Prove - Implements the C<prove> command.

=head1 VERSION

Version 2.99_05

=cut

$VERSION = '2.99_05';

my $IS_WIN32 = ( $^O =~ /^(MS)?Win32$/ );
my $NEED_GLOB = $IS_WIN32;

use constant PLUGINS => 'App::Prove::Plugin';

my @ATTR;

BEGIN {
    @ATTR = qw(
      archive argv blib color directives exec failures fork formatter
      harness includes modules plugins jobs lib merge parse quiet really_quiet recurse
      backwards shuffle taint_fail taint_warn timer verbose
      warnings_fail warnings_warn show_help show_man show_version
    );
    for my $attr (@ATTR) {
        no strict 'refs';
        *$attr = sub {
            my $self = shift;
            croak "$attr is read-only" if @_;
            $self->{$attr};
        };
    }
}

=head1 METHODS

=head2 Class Methods

=head3 C<new>

=cut

sub new {
    my $class = shift;
    my $args = shift || {};

    my $self = bless {
        argv     => [],
        includes => [],
        modules  => [],
        plugins  => [],
    }, $class;

    for my $attr (@ATTR) {
        if ( exists $args->{$attr} ) {

            # TODO: Some validation here
            $self->{$attr} = $args->{$attr};
        }
    }
    return $self;
}

=head3 C<process_args>

  $prove->process_args(@args);

Processes the command-line arguments and stashes the remainders in the
C<$self->{args}> array-ref.

Dies on invalid arguments.

=cut

sub process_args {
    my ( $self, @args ) = @_;

    if ( my @bad = map {"-$_"} grep {/^-(man|help)$/} @args ) {
        die "Long options should be written with two dashes: ",
          join( ', ', @bad ), "\n";
    }

    # Allow cuddling the paths with the -I
    @args = map { /^(-I)(.+)/ ? ( $1, $2 ) : $_ } @args;

    {
        local @ARGV = @args;
        Getopt::Long::Configure( 'no_ignore_case', 'bundling' );

        # Don't add coderefs to GetOptions
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
            'fork'        => \$self->{fork},
            'p|parse'     => \$self->{parse},
            'q|quiet'     => \$self->{quiet},
            'Q|QUIET'     => \$self->{really_quiet},
            'e|exec=s'    => \$self->{exec},
            'm|merge'     => \$self->{merge},
            'I=s@'        => $self->{includes},
            'M=s@'        => $self->{modules},
            'P=s@'        => $self->{plugins},
            'directives'  => \$self->{directives},
            'h|help|?'    => \$self->{show_help},
            'H|man'       => \$self->{show_man},
            'V|version'   => \$self->{show_version},
            'a|archive=s' => \$self->{archive},
            'j|jobs=i'    => \$self->{jobs},
            'timer'       => \$self->{timer},
            'T'           => \$self->{taint_fail},
            't'           => \$self->{taint_warn},
            'W'           => \$self->{warnings_fail},
            'w'           => \$self->{warnings_warn},
        ) or croak('Unable to continue');

        # Stash the remainder of argv for later
        $self->{argv} = [@ARGV];
    }

    return;
}

sub _exit { exit( $_[1] || 0 ) }

sub _help {
    my ( $self, $verbosity ) = @_;

    eval('use Pod::Usage 1.12 ()');
    if ( my $err = $@ ) {
        die 'Please install Pod::Usage for the --help option '
          . '(or try `perldoc prove`.)'
          . "\n ($@)";
    }

    Pod::Usage::pod2usage( { -verbose => $verbosity } );

    return;
}

sub _color_default {
    my $self = shift;

    return -t STDOUT && !$IS_WIN32;
}

sub _get_args {
    my $self = shift;

    $self->{harness_class} = 'TAP::Harness';

    my %args;

    if ( defined $self->color ? $self->color : $self->_color_default ) {
        $args{color} = 1;
    }

    if ( $self->archive ) {
        eval('sub TAP::Harness::Archive::auto_inherit {1}');    # wink,wink
        $self->require_harness( archive => 'TAP::Harness::Archive' );
        $args{archive} = $self->archive;
    }

    if ( my $jobs = $self->jobs ) {
        $args{jobs} = $jobs;
    }

    if ( my $fork = $self->fork ) {
        $args{fork} = $fork;
    }

    if ( my $harness_opt = $self->harness ) {
        $self->require_harness( harness => $harness_opt );
    }

    if ( my $formatter = $self->formatter ) {
        $args{formatter_class} = $formatter;
    }

    if ( $self->taint_fail && $self->taint_warn ) {
        die '-t and -T are mutually exclusive';
    }

    if ( $self->warnings_fail && $self->warnings_warn ) {
        die '-w and -W are mutually exclusive';
    }

    for my $a (qw( lib switches )) {
        my $method = "_get_$a";
        my $val    = $self->$method();
        $args{$a} = $val if defined $val;
    }

    for my $a (qw( merge verbose failures timer )) {
        $args{$a} = $self->$a() if $self->$a();
    }

    for my $a (qw( quiet really_quiet directives )) {
        $args{$a} = 1 if $self->$a();
    }

    $args{errors} = 1 if $self->parse;

    # defined but zero-length exec runs test files as binaries
    $args{exec} = [ split( /\s+/, $self->exec ) ]
      if ( defined( $self->exec ) );

    return ( \%args, $self->{harness_class} );
}

sub _find_module {
    my ( $self, $class, @search ) = @_;

    croak "Bad module name $class"
      unless $class =~ /^ \w+ (?: :: \w+ ) *$/x;

    for my $pfx (@search) {
        my $name = join( '::', $pfx, $class );
        print "$name\n";
        eval "require $name";
        return $name unless $@;
    }

    eval "require $class";
    return $class unless $@;
    return;
}

sub _load_extension {
    my ( $self, $class, @search ) = @_;

    my @args = ();
    if ( $class =~ /^(.*?)=(.*)/ ) {
        $class = $1;
        @args = split( /,/, $2 );
    }

    if ( my $name = $self->_find_module( $class, @search ) ) {
        $name->import(@args);
    }
    else {
        croak "Can't load module $class";
    }
}

sub _load_extensions {
    my ( $self, $ext, @search ) = @_;
    $self->_load_extension( $_, @search ) for @$ext;
}

=head3 C<run>

=cut

sub run {
    my $self = shift;

    if ( $self->show_help ) {
        $self->_help(1);
    }
    elsif ( $self->show_man ) {
        $self->_help(2);
    }
    elsif ( $self->show_version ) {
        $self->print_version;
    }
    else {

        $self->_load_extensions( $self->modules );
        $self->_load_extensions( $self->plugins, PLUGINS );

        my @tests = $self->_get_tests( @{ $self->argv } );

        $self->_shuffle(@tests) if $self->shuffle;
        @tests = reverse @tests if $self->backwards;

        $self->_runtests( $self->_get_args, @tests );
    }

    return;
}

sub _runtests {
    my ( $self, $args, $harness_class, @tests ) = @_;
    my $harness    = $harness_class->new($args);
    my $aggregator = $harness->runtests(@tests);

    $self->_exit( $aggregator->has_problems ? 1 : 0 );

    return;
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

    unless (@argv) {
        croak "No tests named and 't' directory not found"
          unless -d 't';
        @argv = 't';
    }

    # Do globbing on Win32.
    if ($NEED_GLOB) {
        @argv = map { glob "$_" } @argv;
    }

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
    return;
}

=head3 C<require_harness>

Load a harness class and add it to the inheritance chain.

  $prove->require_harness($for => $class_name);

=cut

sub require_harness {
    my ( $self, $for, $class ) = @_;

    eval("require $class");
    die "$class is required to use the --$for feature: $@" if $@;
    $class->inherit( $self->{harness_class} );

    $self->{harness_class} = $class;

    return;
}

=head3 C<print_version>

=cut

sub print_version {
    my $self = shift;
    printf(
        "TAP::Harness v%s and Perl v%vd\n",
        $TAP::Harness::VERSION, $^V
    );

    return;
}

1;

__END__

=head2 Attributes

=over

=item C<archive>

=item C<argv>

=item C<backwards>

=item C<blib>

=item C<color>

=item C<directives>

=item C<exec>

=item C<failures>

=item C<fork>

=item C<formatter>

=item C<harness>

=item C<includes>

=item C<jobs>

=item C<lib>

=item C<merge>

=item C<modules>

=item C<parse>

=item C<plugins>

=item C<quiet>

=item C<really_quiet>

=item C<recurse>

=item C<show_help>

=item C<show_man>

=item C<show_version>

=item C<shuffle>

=item C<taint_fail>

=item C<taint_warn>

=item C<timer>

=item C<verbose>

=item C<warnings_fail>

=item C<warnings_warn>

=back

# vim:ts=4:sw=4:et:sta
