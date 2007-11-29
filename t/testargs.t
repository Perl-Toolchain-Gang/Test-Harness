#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 8;
use File::Spec;
use TAP::Parser;

my $test = File::Spec->catfile( 't', 'sample-tests', 'echo' );

sub echo_ok {
    my @args   = @_;
    my $parser = TAP::Parser->new( { source => $test, test_args => \@args } );
    my @got    = ();
    while ( my $result = $parser->next ) {
        push @got, $result;
    }
    my $plan = shift @got;
    ok $plan->is_plan;
    for (@got) {
        is $_->description, shift(@args), "option passed OK";
    }
}

echo_ok(qw( yes no maybe ));
echo_ok(qw( 1 2 3 ));
