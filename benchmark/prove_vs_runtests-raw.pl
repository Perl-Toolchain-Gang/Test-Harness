#!/usr/bin/perl

# compare raw throughput speed of prove vs runtests

use warnings;
use strict;

use Benchmark qw(:hireswallclock);
use File::Temp ();
use Cwd ();
use Config;

my %knobs = (
    num_lines      => 1000,
    num_test_files => 10,
    num_runs       => 1,
    noisy          => 0,
);

if(1) { # header
    my @mods = qw(
        TAP::Parser
        Test::Harness
    );
    require $_ for(map({(my $m = $_) =~ s#::#/#g; $m.'.pm'} @mods));

    print "This is perl $] on $^O ($Config{archname})\n";
    printf(join("\n  ", "Using ", ("%s version %s")x@mods) . "\n",
      map({$_, $_->VERSION} @mods)
    );
    print "\n";
}

my $tmp_dir = File::Temp::tempdir(
    'tapx-' . 'X'x8,
    TMPDIR => 1,
    CLEANUP => 1,
) . '/';

my $pwd = Cwd::getcwd();
chdir($tmp_dir) or die "cannot get into $tmp_dir $!";
mkdir('t') or die "cannot create t directory $!";

# just checking raw output handling speed
my $thetest = 'my $n = ' . $knobs{num_lines} . ';' .
    <<'THETEST';
    print "1..$n\n";
    print "ok $_\n" for (1..$n);
    # print "#$0";
THETEST

for my $num (1..$knobs{num_test_files}) {
    my $testfile = sprintf('t/%02d-test.t', $num);
    open(my $fh, '>', $testfile) or
        die "cannot open '$testfile' for writing $!";
    print $fh $thetest;
}

my $perl = $^X;
my @prove    = ('prove', 't/');
my @runtests = ('runtests');

my $catch_out = sub {
    open(my $TO_OUT, "<&STDOUT") or die "ack1\n";
    close(STDOUT) or die "ack2\n";
    my $catch = '';
    open(STDOUT, '>', \$catch);

    $_[0]->();

    open(STDOUT, ">&", $TO_OUT) or die "ack3\n";
    close($TO_OUT) or die "ack4\n";
};

# XXX is quite different if STDOUT is a terminal?
$catch_out = sub {$_[0]->()} if($knobs{noisy});

sub time_this {
    my ($name, $sub) = @_;

    my $n = $knobs{num_runs};
    my $t;
    $catch_out->(sub {$t = Benchmark::timeit($n, $sub)});

    my $out = Benchmark::timestr($t);
    $out =~ s/\(.*sys \+ */(/;
    print $name, "\n  $out\n\n";

    return($name, $t);
}

my $res = {
    time_this(prove    => sub {system(@prove) and die;}),
    time_this(runtests => sub {system(@runtests) and die;}),
};

# Ah, the secret is to use the 'nop' to show children
Benchmark::cmpthese($res, 'nop');


# vim:ts=4:sw=4:et:sta
