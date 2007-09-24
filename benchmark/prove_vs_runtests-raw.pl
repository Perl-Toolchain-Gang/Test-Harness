#!/usr/bin/perl

# compare raw throughput speed of prove vs runtests

use warnings;
use strict;

use Getopt::Long ();
use Benchmark qw(:hireswallclock);
use File::Temp ();
use File::Spec ();
use Cwd        ();
use Config;

my %knobs = (
    num_lines      => 1000,
    num_test_files => 10,
    num_runs       => 1,
    noisy          => 0,
    named          => 1,
    prove          => 1,
    runtests       => 1,
);
Getopt::Long::GetOptions(
    \%knobs,
    'num_lines=i',
    'num_test_files=i',
    'num_runs=i',
    'noisy',
    'named!',
    'prove!',
    'runtests!',
) or die "bad options";

if (0) {    # header
    my @mods = qw(
      TAP::Parser
      Test::Harness
    );
    require $_
      for (
        map( {  ( my $m = $_ ) =~ s#::#/#g;
                  $m . '.pm'
            } @mods )
      );

    print "This is perl $] on $^O ($Config{archname})\n";
    printf(
        join( "\n  ", "Using ", ("%s version %s") x @mods ) . "\n",
        map( { $_, $_->VERSION } @mods )
    );
    print "\n";
}

# for historical benchmarks
# (because we renamed this, but had both once)
my $prove_or_runtests = ( -e 'bin/runtests' ? 'bin/runtests' : 'bin/prove' );

my $tmp_dir = File::Temp::tempdir(
    'tapx-' . 'X' x 8,
    TMPDIR  => 1,
    CLEANUP => 1,
) . '/';

my $pwd = Cwd::getcwd();
chdir($tmp_dir) or die "cannot get into $tmp_dir $!";
mkdir('t')      or die "cannot create t directory $!";

# just checking raw output handling speed
my $thetest
  = 'my $n = '
  . $knobs{num_lines} . ';'
  . q(print "1..$n\n";)
  . q(print "ok $_)
  . ( $knobs{named} ? ' whee' : '' )
  . q(\n" for (1..$n);)
  . q(# print "#$0";);

for my $num ( 1 .. $knobs{num_test_files} ) {
    my $testfile = sprintf( 't/%02d-test.t', $num );
    open( my $fh, '>', $testfile )
      or die "cannot open '$testfile' for writing $!";
    print $fh $thetest;
}

my $perl   = $^X;
my $th_dir = 'reference/Test-Harness-2.64';
my @prove  = (
    $perl,
    '-I' . File::Spec->catfile( $pwd, $th_dir, 'lib' ),
    File::Spec->catfile( $pwd,        $th_dir, 'bin/prove' ),
    't/'
);
my @runtests = (
    $perl,
    '-I' . File::Spec->catfile( $pwd, 'lib' ),
    File::Spec->catfile( $pwd,        $prove_or_runtests )
);

my $catch_out = sub {    # hmm, should just IPC::Run?
    open( my $TO_OUT, "<&STDOUT" ) or die "ack1\n";
    close(STDOUT) or die "ack2\n";
    my $catch = '';
    open( STDOUT, '>', \$catch );

    $_[0]->();

    open( STDOUT, ">&", $TO_OUT ) or die "ack3\n";
    close($TO_OUT) or die "ack4\n";
};

# XXX is quite different if STDOUT is a terminal?
$catch_out = sub { $_[0]->() }
  if ( $knobs{noisy} );

sub time_this {
    my ( $name, $sub ) = @_;

    my $n = $knobs{num_runs};
    my $t;
    $catch_out->( sub { $t = Benchmark::timeit( $n, $sub ) } );

    my $out = Benchmark::timestr($t);
    $out =~ s/\(.*sys \+ */(/;
    print $name, "\n  $out\n\n";

    return ( $name, $t );
}

if ( $knobs{noisy} ) {
    warn "prove:    ", join( " ", @prove ),    "\n";
    warn "runtests: ", join( " ", @runtests ), "\n";
}

my $res = {
    (   $knobs{prove} ? time_this( prove => sub { system(@prove) and die; } )
        : ()
    ),
    (   $knobs{runtests}
        ? time_this( runtests => sub { system(@runtests) and die; } )
        : ()
    ),
};

# Ah, the secret is to use the 'nop' to show children
$knobs{prove} and Benchmark::cmpthese( $res, 'nop' );

# fake yaml
print "---\n";
printf( "${_}: %0.3f\n", $res->{$_}[0] ) for ( keys %$res );

# vim:ts=4:sw=4:et:sta
