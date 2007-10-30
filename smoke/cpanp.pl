#!/usr/bin/perl
#
# Run our tests under CPANPLUS.
# This code indulges in serious abuse of CPANPLUS internals.

use strict;
use warnings;
use CPANPLUS::Configure;
use CPANPLUS::Backend;
use CPANPLUS::Internals::Constants;
use Cwd;

my %opt_map = (
    '--mm'    => INSTALLER_MM,
    '--build' => INSTALLER_BUILD
);

if ( grep { $_ eq '--help' || $_ eq '-h' } @ARGV ) {
    die "cpanp.pl --mm | --build\n";
}

my @run = map { $opt_map{$_} || die "Bad option: $_\n" } @ARGV;

die "Please specify --mm or --build\n"
  unless @run;

my $home = getcwd();

my $conf = CPANPLUS::Configure->new;

# Don't send a report
$conf->set_conf( 'cpantest', 0 );

my $cb = CPANPLUS::Backend->new;

# Path isn't used because we...
my $mod = $cb->parse_module( module => "file:///$home" );

# ...pretend we've already extracted it.
$mod->status->extract($home);

my $failed = 0;

for my $type (@run) {
    $mod->status->installer_type($type);

    # Run the tests
    $failed++ unless $mod->test;
}

# Probably don't get this far. Probably doesn't matter.
exit $failed;
