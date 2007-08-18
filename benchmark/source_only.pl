#!/usr/bin/perl

use strict;
use warnings;
use TAP::Parser::Iterator;

my $test = shift || die "No test named";

my $iter = TAP::Parser::Iterator->new( { command => [ $^X, $test ] } );
while ( defined( my $line = $iter->next ) ) {

    # Do nothing
}
