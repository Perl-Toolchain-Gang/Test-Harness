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

use Test::More tests => 4;

use File::Spec;

use_ok( 'TAP::Parser::Source' );

# Basic tests
my $source = TAP::Parser::Source->new;
isa_ok( $source, 'TAP::Parser::Source', 'new source' );
can_ok( $source, qw( raw meta config merge switches test_args assemble_meta ) );

$source->raw( \'hello world' );
my $meta = $source->assemble_meta;
is_deeply( $meta, {
		   scalar       => 1,
		   has_newlines => 0,
		   length       => 11,
		   is_object    => 0,
		  }, 'assemble_meta' );


# TODO: include file, dir & symlink test cases


# y  the raw source
# y  params (merge, switches, test_args)
# y  meta (assembles it too)
# (note to self: include shebang for Perl source)
# ?  config?
# y  move meta data assembling from SourceFactory
# ?  could have different sub-classes for internal cases



