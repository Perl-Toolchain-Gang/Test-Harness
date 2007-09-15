#!/usr/bin/perl

# runs multiple copies of the repository against the latest benchmark
# assumes unix (linux even?) -- feel free to fix that
# still needs to compare/tabulate the results
#   (wouldn't hurt to run prove only once)
# started by Eric Wilhelm

use warnings;
use strict;

use IPC::Run ();

my $basedir = shift(@ARGV) || '/tmp/tapx-history';
unless(-d $basedir) {
  mkdir($basedir) or die "cannot create $basedir";
}

my @revs = (
    270, # pre speedy branch
    309, # pre merge
    310, # speedy merge
    461, # console output (broke Parallel)
    463, # undo console output
    494, # major console output phase 1
    534, # lots of formatting (phase 2)
    535, # grammar streamline
    537, # remove _trim() redundancy
);

my $url = 'http://svn.hexten.net/tapx/trunk';

my $bm_file = 'benchmark/prove_vs_runtests-raw.pl';
my $bm_source = File::Spec->rel2abs($bm_file);

chdir($basedir) or die "cannot chdir $!";

my $trunk = 'trunk';

if(-e $trunk) {
    do_svn(qw(up), $trunk);
}
else {
    do_svn(qw(co -q ), $url);
}

if(-e 'trunk.cached') {
    unlink('trunk.cached') or die "ugh, cannot delete trunk.cached $!";
}

# first get them all setup
foreach my $rev (@revs) {
    if(-e $rev) {
        #warn "update $rev/benchmark\n";
        #do_svn(qw(up -q), "$rev/benchmark");
    }
    else {
        system('cp', '-a', 'trunk', $rev) and die "ack $? $!";
        do_svn(qw(up -q -r ), $rev, "$rev/lib", "$rev/bin");
    }

    # TODO only if newer (and then invalidate cache, etc)
    system('cp', $bm_source, "$rev/benchmark/") and die;
}

foreach my $rev (@revs, 'trunk') {

    print "#"x72, "\n";
    my $cached_file = "$rev.cached";
    if(-e $cached_file) {
        open(my $fh, '<', $cached_file) or
            die "cannot open cache $cached_file $!";
        print "cached r$rev\n";
        print <$fh>;
        next;
    }

    open(my $fh, '>', $cached_file) or die "$!";

    chdir($rev) or die $!;
    print "running r$rev\n";
    my $err;
    IPC::Run::run(
        [ $^X, $bm_file ],
        '>'  => sub {print $fh @_; print @_}, # tee
        '2>' => \$err,
    ) or die "now what $? $! $err";
    chdir($basedir) or die $!;
}

sub do_svn {
    my @command = @_;
    $ENV{NOSVN} and return;
    system('svn', @command) and
        die "svn @command failed $? $!";
}

# vim:ts=4:sw=4:et:sta
