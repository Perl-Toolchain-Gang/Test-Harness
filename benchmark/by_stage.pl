#!/usr/bin/perl

use strict;
use warnings;
use IPC::Open3;
use IO::Select;
use IO::Handle;
use YAML qw( LoadFile DumpFile );
use Term::ANSIColor qw( :constants );
use Getopt::Long;
use File::Which;

my $TEST          = 'tmassive/huge.t';
my $BASELINE_FILE = 'baseline.yaml';
my $PERL          = $^X;
my @SWITCHES      = ('-I../lib');

my %SPECIAL = (
    runtests => '../bin/runtests',
    prove    => scalar which('prove'),
);

my @STAGES = qw( source grammar parser runtests prove );

GetOptions( 'baseline' => \my $BASELINE ) or syntax();

my $baseline = -f $BASELINE_FILE ? LoadFile($BASELINE_FILE) : undef;
my $current = {};

my %last = ();
for my $stage (@STAGES) {
    my $script = $SPECIAL{$stage} || "${stage}_only.pl";
    my @cmd = ( 'time', '-p', $PERL, @SWITCHES, $script, $TEST );

    my $cmd = join ' ', @cmd;
    print ">>> $cmd <<<\n";

    my ( $status, $stdout, $stderr ) = capture_command(@cmd);
    my $result = {};
    for (@$stderr) {
        next unless /^(\w+)\s+(\d+(?:[.]\d+)?)$/;
        print "$1 $2";
        $result->{$1} = $2;
        print ' ', $2 - $last{$1} if exists $last{$1};
        print "\n";
    }
    %last = %{ $current->{$stage} = $result };
}

if ($baseline) {
    for my $stage (@STAGES) {
        print "$stage\n";
        if ( my $result = $baseline->{$stage} ) {
            for my $type (qw( real user sys )) {
                print "  $type ";
                if (   ( my $base_time = $result->{$type} )
                    && ( my $cur_time = $current->{$stage}->{$type} ) )
                {
                    my $delta = $cur_time - $base_time;
                    my $color
                      = ( abs($delta) > ( $cur_time + $base_time ) / 50 )
                      ? ( $delta > 0 )
                          ? RED
                          : GREEN
                      : '';
                    print "$cur_time v $base_time, delta: $color$delta",
                      RESET;
                }
                else {
                    print "not available";
                }
                print "\n";
            }
        }
        else {
            print "  No baseline\n";
        }
    }
}

if ($BASELINE) {
    DumpFile( $BASELINE_FILE, $current );
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

sub syntax {
    die "by_stage.pl [--baseline]\n";
}
