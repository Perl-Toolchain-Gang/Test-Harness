#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Path;
use File::Copy;
use Getopt::Long;
use File::chdir;

$| = 1;

my @to_core = (
    'bin/prove'                       => 'lib/Test/Harness/bin/prove',
    'Changes'                         => 'lib/Test/Harness/Changes',
    'lib/App/Prove.pm'                => 'lib/App/Prove.pm',
    'lib/App/Prove/State.pm'          => 'lib/App/Prove/State.pm',
    'lib/TAP'                         => 'lib/TAP',
    'lib/Test/Harness.pm'             => 'lib/Test/Harness.pm',
    't'                               => 'lib/Test/Harness/t',
    't/compat'                        => 'lib/Test/Harness/t/compat',
    't/data'                          => 't/lib/data',
    't/lib/App/Prove/Plugin/Dummy.pm' => 't/lib/App/Prove/Plugin/Dummy.pm',
    't/lib/Dev/Null.pm'               => 't/lib/Dev/Null.pm',
    't/lib/if.pm'                     => 'lib/if.pm',
    't/lib/IO/c55Capture.pm'          => 't/lib/IO/c55Capture.pm',
    't/lib/NoFork.pm'                 => 't/lib/NoFork.pm',
    't/sample-tests'                  => 't/lib/sample-tests',
    't/source_tests'                  => 't/lib/source_tests',

    # Files that we don't include that would match the above rules. All
    # of these would match the 't' rule.
    't/lib/Test/Builder.pm'        => undef,
    't/lib/Test/Builder/Module.pm' => undef,
    't/lib/Test/More.pm'           => undef,
    't/lib/Test/Simple.pm'         => undef,
);

my %opt = ();

Getopt::Long::Configure( 'no_ignore_case', 'bundling' );
GetOptions(
    'verbose' => \$opt{verbose},
    'help'    => \$opt{help}
) or die "Bad options, stopping\n";

if ( $opt{help} ) {
    help();
    exit;
}

die "core-tool.pl needs three arguments\n" unless @ARGV == 3;
my ( $cmd, $dist, $core ) = @ARGV;

sanity_check_dist($dist);
sanity_check_core($core);

my %despatch = (
    c2d => sub {
        my ( $dist, $core ) = @_;

        # Compute the diff from core to dist
        diff_files( $dist, $core, get_file_map( $dist, $core ) );
    },
    d2c => sub {
        my ( $dist, $core ) = @_;

        # Compute the diff from dist to core
        diff_files( $core, $dist, reverse get_file_map( $dist, $core ) );
    }
);

if ( my $handler = $despatch{$cmd} ) {
    $handler->( $dist, $core );
}
else {
    die "Unknown command: $cmd. Valid commands are: ",
      join( ', ', sort keys %despatch ), "\n";
}

# Get a list of dist_file => core_file pairs. Reverse to map the other way
sub get_file_map {
    my ( $dist, $core ) = @_;
    my $manifest = File::Spec->catfile( $dist, 'MANIFEST' );
    my @file_map = ();
    open my $mh, '<', $manifest or die "Can't read $manifest ($!)\n";
    while ( my $dist_file = <$mh> ) {
        chomp $dist_file;
        if ( defined( my $core_file = lookup( $dist_file, @to_core ) ) ) {
            push @file_map, $dist_file, $core_file;
        }
    }
    return @file_map;
}

# Do a longest leading substring match.
sub lookup {
    my ( $name, @name_map ) = @_;
    my ( $longest, $match ) = ( '', undef );
    while ( my ( $from, $to ) = splice @name_map, 0, 2 ) {

        # Exact?
        return $to if $name eq $from;

        # Better match?
        my $lf = length $from;
        if ( $lf > length $longest
            && substr( $name, 0, $lf + 1 ) eq "$from/" )
        {
            $longest = $from;
            $match   = $to;
        }
    }
    return unless defined $match;
    return $match . substr( $name, length $longest );
}

sub diff_files {
    with_pairs(
        sub {
            system( qw( diff -uNr ), @_ );
        },
        @_
    );
}

sub with_pairs {
    my ( $act, $from_dir, $to_dir, @file_map ) = @_;
    $to_dir = File::Spec->rel2abs($to_dir);
    local $CWD = $from_dir;
    while ( my ( $from_file, $to_file ) = splice @file_map, 0, 2 ) {
        $act->( $from_file, File::Spec->catfile( $to_dir, $to_file ) );
    }
}

sub help {
    print "core-tool.pl <command> <dist> <core>";
}

sub sanity_check {
    my ( $dir, $type, @want ) = @_;
    my @missing = grep { !-f } map { File::Spec->catfile( $dir, $_ ) } @want;
    if (@missing) {
        die "$dir doesn't look like a $type directory.\n"
          . "The following expected files are missing:\n  ",
          join( "\n  ", sort @missing ), "\n";
    }
}

{
    my @common = qw(
      Changes
      MANIFEST
      README
    );

    sub sanity_check_core {
        my $core = shift;
        sanity_check(
            $core, 'core', @common, qw(
              Artistic
              EXTERN.h
              INTERN.h
              )
        );
    }

    sub sanity_check_dist {
        my $dist = shift;
        sanity_check(
            $dist, 'dist', @common, qw(
              Build.PL
              HACKING.pod
              Makefile.PL
              )
        );
    }
}
