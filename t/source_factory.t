#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', '../ext/Test-Harness/t/lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::More tests => 10;

use File::Spec;
use TAP::Parser::SourceFactory;

can_ok 'TAP::Parser::SourceFactory', 'new';
my $sf = TAP::Parser::SourceFactory->new;
isa_ok $sf, 'TAP::Parser::SourceFactory';
can_ok $sf, 'detect_source';
can_ok $sf, 'make_source';
can_ok $sf, 'register_detector';

# Register a detector
use_ok( 'MySourceDetector' );
is_deeply( $sf->detectors, ['MySourceDetector'], '... was registered' );

# Known source should pass
{
    my $source;
    eval { $source = $sf->make_source(\"known-source") };
    my $error = $@;
    ok( ! $error, 'make_source with known source doesnt fail' );
    diag( $error ) if $error;
}

# No known source should fail
{
    my $source;
    eval { $source = $sf->make_source(\"unknown-source") };
    my $error = $@;
    ok( $error, 'make_source with unknown source fails' );
    like $error, qr/^Couldn't detect source of 'unknown-source'/,
      '... with an appropriate error message';
}
