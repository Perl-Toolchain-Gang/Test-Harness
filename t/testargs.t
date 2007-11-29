#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 16;
use File::Spec;
use TAP::Parser;

my $test = File::Spec->catfile( 't', 'sample-tests', 'echo' );

sub echo_ok {
    my $options = shift;
    my @args    = @_;
    my $parser  = TAP::Parser->new( { %$options, test_args => \@args } );
    my @got     = ();
    while ( my $result = $parser->next ) {
        push @got, $result;
    }
    my $plan = shift @got;
    ok $plan->is_plan;
    for (@got) {
        is $_->description, shift(@args),
          join( ', ', keys %$options ) . ": option passed OK";
    }
}

for my $args ( [qw( yes no maybe )], [qw( 1 2 3 )] ) {
    echo_ok( { source => $test }, @$args );
    echo_ok( { exec => [ $^X, $test ] }, @$args );
}
