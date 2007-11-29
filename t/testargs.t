#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 19;
use File::Spec;
use TAP::Parser;
use TAP::Harness;
use App::Prove;

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

{
    my $harness = TAP::Harness->new(
        { verbosity => -9, test_args => [qw( magic hat brigade )] } );
    my $aggregate = $harness->runtests($test);

    is $aggregate->total,  3, "ran the right number of tests";
    is $aggregate->passed, 3, "and they passed";
}

package Test::Prove;

use vars qw(@ISA);
@ISA = 'App::Prove';

sub _runtests {
    my $self = shift;
    push @{ $self->{_log} }, [@_];
    return;
}

sub get_run_log {
    my $self = shift;
    return $self->{_log};
}

package main;

{
    my $app = Test::Prove->new;

    $app->process_args( $test, '--', 'one', 'two', 'huh' );
    $app->run();
    my $log = $app->get_run_log;
    is_deeply $log->[0]->[0]->{test_args}, [ 'one', 'two', 'huh' ],
      "prove args match";
}
