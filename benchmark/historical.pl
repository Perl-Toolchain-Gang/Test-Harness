#!/usr/bin/perl

# runs multiple copies of the repository against the latest benchmark
# assumes unix (linux even?) -- feel free to fix that
# still needs to compare/tabulate the results better
# running a local copy might be nice too
# started by Eric Wilhelm

use warnings;
use strict;

use IPC::Run ();
use YAML;

my $basedir = shift(@ARGV) || '/tmp/tapx-history';
unless ( -d $basedir ) {
    mkdir($basedir) or die "cannot create $basedir";
}

my $revs = <<REVISIONS;
    270 pre speedy branch
    309 pre merge
    310 speedy merge
    461 console output (broke Parallel)
    463 undo console output
    494 major console output phase 1
    534 lots of formatting (phase 2)
    535 grammar streamline
    537 remove _trim() redundancy
    543 conditional utf8
    545 More minor performance gains
    546 Another small speed hike
    547 More minor speed-ups
    548 Banish accessor bloat
    554 More accessor shaving
    837 Before nested TAP
REVISIONS

# parse it out into a map and list
my @revs = map( {
        s/^\s*//;
          [ split( /\s+/, $_, 2 ) ]
    }
    grep( { $_ !~ m/^\s*#/ } split( /\n/, $revs ) ) );
my %revmap = map( { $_->[0] => $_->[1] } @revs );
@revs = map( { $_->[0] } @revs );

my $url = 'http://svn.hexten.net/tapx/trunk';

my $bm_file   = 'benchmark/prove_vs_runtests-raw.pl';
my $bm_source = File::Spec->rel2abs($bm_file);

chdir($basedir) or die "cannot chdir $!";

my $trunk = 'trunk';

if ( -e $trunk ) {
    do_svn( qw(up), $trunk );
}
else {
    do_svn( qw(co -q ), $url );
}

if ( -e 'trunk.cached' ) {
    unlink('trunk.cached') or die "ugh, cannot delete trunk.cached $!";
}

# first get them all setup
foreach my $rev (@revs) {
    if ( -e $rev ) {

        #warn "update $rev/benchmark\n";
        #do_svn(qw(up -q), "$rev/benchmark");
    }
    else {
        system( 'cp', '-r', 'trunk', $rev ) and die "ack $? $!";
        do_svn( qw(up -q -r ), $rev, "$rev/lib", "$rev/bin" );
    }

    # TODO only if newer (and then invalidate cache, etc)
    system( 'cp', $bm_source, "$rev/benchmark/" ) and die;
}

system( 'cp', $bm_source, "trunk/benchmark/" ) and die;

my %revdata;
my $prove_time;
my $storedata = sub {
    my ( $rev, $data ) = @_;
    my @lines = split( /\n/, $data );

    # the last (only) yaml marker
    my @markers = grep( { $lines[$_] =~ m/^---(?:\s|$)/ } 0 .. $#lines );
    my @yaml = map( { $lines[$_] } $markers[-1] .. $#lines );
    my ($hash) = YAML::Load( join( "\n", @yaml, '' ) );
    if ( $rev eq 'prove' ) {
        return ( $hash->{prove}, $hash->{sp_factor} );
    }
    $revdata{$rev} = $hash->{runtests};
};

push( @revs, 'trunk' );

# define 'speed points' so we can shift the values around and then
# normalize back to the 1.00-2.00 range
my %knobs = (
    num_lines      => 5000,
    num_test_files => 10,
    num_runs       => 5,
);
my $sp_factor
  = ( $knobs{num_lines} / 1000 ) 
  * ( $knobs{num_test_files} / 10 )
  * ( $knobs{num_runs} / 1 );
warn "speed factor: $sp_factor\n";
my @opts = (
    map( { '--' . $_, $knobs{$_} } keys(%knobs) ),
);

# get/check the prove value
my $cache_ok = 0;
{
    my $cached_file = 'prove.cached';
    if ( my $out = check_cache($cached_file) ) {
        my $check_sp;
        ( $prove_time, $check_sp ) = $storedata->( 'prove', $out );

        # verify that the settings haven't changed
        if ( $check_sp == $sp_factor ) {
            $cache_ok = 1;
            print $out;
        }
    }
    unless ($cache_ok) {
        open( my $fh, '>', $cached_file ) or die "$!";
        my $out = run_rev( 'trunk', $fh, @opts, '--no-runtests' );
        print $fh "sp_factor: $sp_factor\n";
        ($prove_time) = $storedata->( 'prove', $out );
    }
}

my $time_est = $prove_time * 1.8 * scalar(@revs);
warn "estimated time: ", sprintf( "%0.0fs", $time_est ),
  ' (' . localtime( time + $time_est ) . ")\n";

foreach my $rev (@revs) {

    print "#" x 72, "\n";
    my $cached_file = "$rev.cached";
    if ( $cache_ok and ( my $out = check_cache($cached_file) ) ) {
        print "cached $rev\n", $out;
        $storedata->( $rev, $out );
        next;
    }

    open( my $fh, '>', $cached_file ) or die "$!";
    my $out = run_rev( $rev, $fh, @opts, '--no-prove' );
    $storedata->( $rev, $out );
}

print "\n\n";
printf( "prove:  1.000 # (by definition) -- %0.3fs\n", $prove_time );
print map( {
        sprintf(
            "%6s %6s # %s\n",
            $_ . ':',
            sprintf( "%0.3f", $revdata{$_} / $prove_time ),    # points
            $revmap{$_} || '-'
        ),                                                     # comment
} @revs );

sub check_cache {
    my ($cached_file) = @_;
    if ( -e $cached_file ) {
        open( my $fh, '<', $cached_file )
          or die "cannot open cache $cached_file $!";
        my $data = do { local $/; <$fh> };
        return ($data);
    }
    return;
}

sub run_rev {
    my ( $rev, $fh, @opts ) = @_;
    chdir($rev) or die $!;
    print "running $rev\n";
    my $err;
    my $out = '';
    my @command = ( $^X, $bm_file, @opts );
    print "@command\n" if ( $rev eq 'trunk' );
    IPC::Run::run(
        [@command],
        '>' =>
          sub { $out .= join( '', @_ ); print $fh @_; print @_ },    # tee
        '2>' => \$err,
    )               or die "now what $? $! $err";
    chdir($basedir) or die $!;
    return ($out);
}

sub do_svn {
    my @command = @_;
    $ENV{NOSVN} and return;
    system( 'svn', @command )
      and die "svn @command failed $? $!";
}

# vim:ts=4:sw=4:et:sta
