#!/usr/bin/perl
#
# Run tests in parallel
#
# From: Eric Wilhelm <scratchcomputing@gmail.com>

use warnings;
use strict;

use File::Basename ();
use File::Path     ();
use List::Util     ();

my @tests = @ARGV;
@tests = List::Util::shuffle( @tests );

my %map;
my $i = 0;

foreach my $test ( @tests ) {
    defined( my $pid = fork ) or die;
    $i++;
    if ( $pid ) {
        $map{$pid} = $test;
    }
    else {
        my $dest_base = '/tmp';
        my $dest_dir  = File::Basename::dirname( "$dest_base/$test" );
        unless ( -d $dest_dir ) {
            File::Path::mkpath( $dest_dir ) or die;
        }

        # this was an interesting hack, but not really needed
        #$ENV{DISPLAY} = ':' . (50 + $i);
        open( STDOUT, '>', "$dest_base/$test.out" ) or die;
        open( STDERR, '>', "$dest_base/$test.err" ) or die;
        if ( 1 ) {
            exec( $^X, '-Ilib', $test );
        }
        else {
            $0 = $test;
            require lib;
            lib->import( 'lib' );
            do( $test );
            exit;
        }
    }
}

my $v = 0;
until ( $v == -1 ) {
    $v = wait;
    ( $v == -1 ) and last;
    $?           and warn "$map{$v} ($v) no happy $?";
}
print "bye\n";

# vim:ts=2:sw=2:et:sta
