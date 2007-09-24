#!/opt/local/bin/perl

use strict;
use warnings;

use Date::Parse;
use File::Path;
use File::Spec;
use File::Temp qw( tempdir );
use File::TinyLock;
use File::chdir;
use Getopt::Long;
use HTML::Tiny;
use IO::Handle;
use IO::Select;
use IPC::Open3;
use RRDTool::OO;
use YAML qw( DumpFile LoadFile );

$| = 1;

use constant MANIFEST => 'MANIFEST';
use constant PREFIX   => 'blib/';

GetOptions(
    'v|verbose' => \my $VERBOSE,
);

die "stats.pl [-v] config\n" unless @ARGV == 1;
my $config = shift;
die "No file $config\n" unless -f $config;

exit if File::TinyLock::lock( $config, TIMEOUT => 1 );

my $Config = load_config($config);
my $Work   = glob $Config->{work};
my $DB     = File::Spec->catdir( $Work, 'db' );

mkpath($DB);

defined $Work or die "No work dir specified\n";
my $Status = load_config( File::Spec->catfile( $Work, 'status' ) );

my $last_rev = $Status->{revision} || ( $Config->{first} - 1 );

# my ( $this_rev, undef ) = get_revision( $Config->{repository} );
#
# print "$this_rev\n";

# for my $rev ( $last_rev + 1 .. $this_rev ) {
#     analyse_rev($rev);
# }

analyse_project('.');

# $Status->{revision} = $this_rev;

sub analyse_rev {
    my $rev = shift;

    mention("Analysing r$rev\n");

    my $dir = tempdir();
    my ( undef, $stamp ) = get_revision( $Config->{repository}, $rev );

    local $CWD = $dir;
    checkout( $Config->{repository}, $rev );
    analyse_project( $dir, $stamp );
}

sub get_rrd_name {
    my $name = shift;
    $name =~ s/[^\w-]+/_/g;
    return File::Spec->catfile( $DB, "$name.rrd" );
}

sub make_rrd_for {
    my ( $file, @sources ) = @_;
    my $rrd_name = get_rrd_name($file);
    my $rrd = RRDTool::OO->new( file => $rrd_name );
    unless ( -e $rrd_name ) {
        mention("Creating $rrd_name");
        $rrd->create(
            (   map {
                    (   data_source => {
                            name      => $_,
                            type      => 'GAUGE',
                            heartbeat => 3600 * 3000,
                        }
                      )
                  } @sources
            ),
            archive => { rows => 200 },

        );
    }
    return $rrd;
}

{
    my %rrd_for = ();

    sub get_rrd_for {
        my ( $file, @sources ) = @_;
        return $rrd_for{$file} ||= make_rrd_for( $file, @sources );
    }
}

sub analyse_project {
    my $dir = shift;
    my $stamp = shift || time();

    local $CWD = $dir;

    my @manifest = read_manifest(MANIFEST);

    my $proj = {
        dir      => $dir,
        manifest => \@manifest,
    };

    my $got_coverage = sub {
        my $rec  = shift;
        my $file = delete $rec->{File};

        # my $rrd  = get_rrd_for( $file, keys %$rec );
        # $rrd->update( time => $stamp, values => $rec );

        # use Data::Dumper;
        # print Dumper($rec);
    };

    # with_command_fatal(
    #     sub { },
    #     qw( perl Build.PL )
    # );
    #
    # with_command_fatal(
    #     parse_coverage( $proj, $got_coverage ),
    #     qw( ./Build testcover )
    # );

    my $parser = parse_coverage( $proj, $got_coverage );

    while (<DATA>) {
        chomp;
        $parser->();
    }

}

sub resolve_coverage_name {
    my ( $proj, $name ) = @_;
    return substr $name, length PREFIX
      unless $name =~ /^\.\.\.(.+)/;
    my @candidate = map substr( $_, length PREFIX ), grep /$1$/,
      map PREFIX . $_, @{ $proj->{manifest} };
    return $candidate[0] if @candidate == 1;
    warn @candidate
      ? (
        "Multiple matches for $name: ", join( ', ', sort @candidate ),
        "\n"
      )
      : "Can't match $name\n";
    return;
}

sub parse_coverage {
    my ( $proj, $cb ) = @_;
    my $state = 'init';

    my $ruler = qr{^-{10,}(?:\s+-+)+\s*$};
    my @fields;

    my $decode = sub {
        my %rec;
        @rec{@fields} = map { $_ eq 'n/a' ? 'U' : $_ }
          split /\s+/, $_[0];
        \%rec;
    };

    my %cov_state = (
        init => {
            test => [
                {   match => $ruler,
                    goto  => 'header',
                },
            ],
        },
        header => {
            test => [
                {   match => qr{^File\b},
                    goto  => 'rule',
                },
                {   goto => 'init',
                }
            ],
            action => sub { @fields = split /\s+/, $_[0] },
        },
        rule => {
            test => [
                {   match => $ruler,
                    goto  => 'stats'
                },
                {   goto => 'init',
                }
            ],
        },
        stats => {
            test => [
                {   match    => qr{^Total\b},
                    continue => 'total',
                }
            ],
            action => sub {
                my $rec = $decode->(@_);
                $rec->{File} = resolve_coverage_name(
                    $proj,
                    delete $rec->{File}
                ) or return;
                $cb->($rec);
            },
        },
        total => {
            test => [
                {   match    => $ruler,
                    continue => 'done'
                },
            ],
            action => sub {
                $cb->( $decode->(@_) );
            },
        },
        done => {},
    );

    return sub {
        my $line = $_;
        STATE: {
            my $st = $cov_state{$state} || die "Bad state: $state\n";

            if ( my $test = $st->{test} ) {
                TEST:
                for my $te ( 'ARRAY' eq ref $test ? @$test : $test ) {
                    next if $te->{match} && $line !~ $te->{match};
                    $state = $te->{goto}
                      || $te->{continue}
                      || die "Missing goto/continue in $state\n";
                    redo STATE if $te->{continue};
                    last TEST;
                }
            }

            if ( my $action = $st->{action} ) {
                $action->($line);
            }
        }
    };
}

sub load_config {
    my ($name) = @_;
    return -f $name ? LoadFile($name) : {};
}

sub save_config {
    my ( $name, $config ) = @_;
    DumpFile( $name, $config );
}

sub mention {
    return unless $VERBOSE;
    print join( '', @_ ), "\n";
}

sub svn_args {
    my ( $verb, $url, $rev ) = @_;
    return (
        $Config->{svn}, $verb,
        ( defined $rev ? ("-r$rev") : () ), $url
    );
}

sub with_command_output {
    my ( $cb, @cmd ) = @_;
    my $cmd = join ' ', @cmd;
    mention($cmd);
    open my $ch, '-|', @cmd or die "Can't $cmd ($!)\n";
    while ( defined( my $line = <$ch> ) ) {
        chomp $line;
        local $_ = $line;
        $cb->();
    }
    close $ch;
    return wantarray ? ( $?, $cmd ) : $?;
}

sub with_command_fatal {
    my ( $cb, @cmd ) = @_;
    my ( $rc, $cmd ) = with_command_output( $cb, @cmd );
    die "$cmd failed: $rc" if $rc;
    return wantarray ? ( $rc, $cmd ) : $rc;
}

sub checkout {
    my ( $url, $rev ) = @_;
    with_command_fatal(
        sub { },
        svn_args( 'checkout', $url, $rev )
    );
}

sub get_revision {
    my $url      = shift;
    my $want_rev = shift;
    my ( $rev, $changed );
    with_command_fatal(
        sub {
            if (/^Revision:\s+(\d+)/) {
                $rev = $1;
            }
            elsif (/^Last\s+Changed\s+Date:\s+(.+)/) {
                my $stamp = $1;
                $stamp =~ s/\s*\([^)]+\)\s*//;
                $changed = str2time($stamp);
            }

        },
        svn_args( 'info', $url, $want_rev )
    );
    return ( $rev, $changed );
}

sub read_manifest {
    my $name = shift;
    open my $fh, '<', $name or die "Can't read $name ($!)\n";
    chomp( my @manifest = grep {/^./} map { s/\s*#.*$//; $_ } <$fh> );
    close $fh;
    return @manifest;
}

END {
    if ( defined $Status ) {
        save_config( File::Spec->catfile( $Work, 'status' ), $Status );
    }
    File::TinyLock::unlock($config);
}

__DATA__
---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
blib/lib/App/Prove.pm          53.1   68.6   37.5   83.8  100.0    2.4   60.4
blib/lib/TAP/Base.pm           97.8   90.0    n/a   92.3  100.0    1.2   95.9
...ib/TAP/Formatter/Color.pm   39.1   18.8    0.0   62.5  100.0    0.0   37.3
.../TAP/Formatter/Console.pm   89.2   75.6   76.0  100.0  100.0    1.2   86.1
...matter/Console/Session.pm   80.6   60.0   48.6  100.0  100.0    1.2   72.7
blib/lib/TAP/Harness.pm        92.0   81.7  100.0   96.4  100.0    1.3   90.7
.../lib/TAP/Harness/Color.pm   39.1   18.8    0.0   62.5  100.0    0.0   37.3
.../Harness/ConsoleOutput.pm    9.5    0.7    1.9   25.7  100.0    0.0    9.0
blib/lib/TAP/Parser.pm        100.0  100.0   96.0  100.0  100.0   14.7   99.8
.../TAP/Parser/Aggregator.pm  100.0   91.7   83.3  100.0  100.0    0.4   96.4
...lib/TAP/Parser/Grammar.pm  100.0  100.0  100.0  100.0  100.0    2.5  100.0
...ib/TAP/Parser/Iterator.pm   90.0  100.0   87.5   87.5  100.0    0.8   91.1
.../Parser/Iterator/Array.pm  100.0  100.0    n/a  100.0  100.0    0.1  100.0
...arser/Iterator/Process.pm   67.0   71.7   33.3   92.7  100.0   54.0   72.5
...Parser/Iterator/Stream.pm  100.0  100.0    n/a  100.0  100.0    0.0  100.0
.../lib/TAP/Parser/Result.pm  100.0  100.0  100.0  100.0  100.0    6.2  100.0
.../Parser/Result/Bailout.pm  100.0    n/a    n/a  100.0  100.0    0.0  100.0
.../Parser/Result/Comment.pm  100.0    n/a    n/a  100.0  100.0    0.1  100.0
...TAP/Parser/Result/Plan.pm  100.0    n/a    n/a  100.0  100.0    0.3  100.0
...TAP/Parser/Result/Test.pm  100.0  100.0  100.0  100.0  100.0    5.2  100.0
.../Parser/Result/Unknown.pm  100.0    n/a    n/a  100.0    n/a    0.0  100.0
.../Parser/Result/Version.pm  100.0    n/a    n/a  100.0  100.0    0.0  100.0
...TAP/Parser/Result/YAML.pm  100.0    n/a    n/a  100.0  100.0    0.0  100.0
.../lib/TAP/Parser/Source.pm  100.0  100.0    n/a  100.0  100.0    0.3  100.0
...TAP/Parser/Source/Perl.pm   94.0   64.3   36.4   94.1  100.0    6.7   83.2
.../Parser/YAMLish/Reader.pm   92.3   80.9   88.9  100.0  100.0    0.5   89.0
.../Parser/YAMLish/Writer.pm   93.8   78.6   50.0   90.9  100.0    0.1   86.1
blib/lib/Test/Harness.pm       99.1   92.9   89.5  100.0  100.0    0.7   96.4
Total                          74.8   65.7   60.9   90.0  100.0  100.0   74.8
---------------------------- ------ ------ ------ ------ ------ ------ ------
