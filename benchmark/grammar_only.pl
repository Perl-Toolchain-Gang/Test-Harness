#!/usr/bin/perl

use strict;
use warnings;

use TAP::Parser::Source;
use TAP::Parser::Grammar;

my $test = shift || die "No test named";

my $iter = TAP::Parser::Iterator->new( { command => [ $^X, $test ] } );
my $grammar = TAP::Parser::Grammar->new($iter);
while ( my $token = $grammar->tokenize ) {

    # Do nothing
}
