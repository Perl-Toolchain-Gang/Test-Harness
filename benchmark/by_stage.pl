#!/usr/bin/perl

use strict;
use warnings;
use IPC::Open3;
use IO::Select;
use IO::Handle;

my $TEST     = 'tmassive/huge.t';
my $PERL     = $^X;
my @SWITCHES = ('-I../lib');

my %SPECIAL = (
    runtests => '../bin/runtests',
    prove    => '/opt/local/bin/prove'
);

my %last = ();
for my $stage (qw< source grammar parser runtests prove >) {
    my $script = $SPECIAL{$stage} || "${stage}_only.pl";
    my @cmd = ( 'time', '-p', $PERL, @SWITCHES, $script, $TEST );

    my $cmd = join ' ', @cmd;
    print ">>> $cmd <<<\n";

    my ( $status, $stdout, $stderr ) = capture_command(@cmd);
    my %result = ();
    for (@$stderr) {
        next unless /^(\w+)\s+(\d+(?:[.]\d+)?)$/;
        print "$1 $2";
        $result{$1} = $2;
        print ' ', $2 - $last{$1} if exists $last{$1};
        print "\n";
    }
    %last = %result;
}

sub capture_command {
    my @cmd = @_;
    my $cmd = join ' ', @cmd;

    my $out = IO::Handle->new;
    my $err = IO::Handle->new;

    my $pid = eval { open3( undef, $out, $err, @cmd ) };
    die "Could not execute ($cmd): $@" if $@;

    my $sel = IO::Select->new( $out, $err );
    my $flip = 0;

    my @stdout = ();
    my @stderr = ();

    while ( my @ready = $sel->can_read ) {
        for my $fh (@ready) {
            if ( defined( my $line = <$fh> ) ) {
                if ( $fh == $err ) {
                    push @stderr, $line;
                }
                else {
                    push @stdout, $line;
                }
            }
            else {
                $sel->remove($fh);
            }
        }
    }

    my $status = undef;
    if ( $pid == waitpid( $pid, 0 ) ) {
        $status = $?;
    }

    return ( $status, \@stdout, \@stderr );
}
