#!/usr/bin/perl

use strict;
use warnings;
use TAP::Parser;

my $test = shift || die "No test named";

my $parser = TAP::Parser->new( { source => $test } );
while ( my $token = $parser->next ) {

    # Do nothing
}
