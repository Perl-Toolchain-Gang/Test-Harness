#!/usr/bin/perl -w

use strict;

use lib 'lib';

use Test::More tests => 144;
use TAPx::Parser::Source;
use File::Spec;

my $test = File::Spec->catfile( 't', 'source_tests', 'varsource' );
my $perl = $^X;

# sub show_state {
#     my ($stream, $where) = @_;
#     my $first = $stream->is_first;
#     my $last  = $stream->is_last;
#     warn "$where, is_first = ",
#             defined $first ? $first : '(undef)',
#             ", is_last = ",
#             defined $last ? $last : '(undef)',
#             "\n";
# }

sub xnor {
    my ( $a, $b ) = @_;
    return ( $a && $b ) || ( !$a && !$b );
}

ok xnor( undef, undef ), 'xnor undef, undef';
ok xnor( 1, 1 ), 'xnor 1, 1';
ok !xnor( undef, 1 ), 'xnor undef, 1';
ok !xnor( 1, undef ), 'xnor 1, undef';

for ( my $lines = 0; $lines < 5; $lines += 0.5 ) {

    # warn "$lines lines\n";
    ok my $source = TAPx::Parser::Source->new, 'new source made ok';
    ok $source->source( [ $perl, '-T', $test, $lines ] );
    ok my $stream = $source->get_stream, 'get_stream works';

    ok !$stream->is_first, 'is_first false before loop';
    ok !$stream->is_last,  'is_last false before loop';

    # show_state($stream, 'before loop');
    for my $ln ( 1 .. int($lines) ) {
        my $next = $stream->next;
        is $next, $ln, 'got correct line';

        my $is_first = $ln == 1;
        my $is_last = $ln == int($lines) && !$is_first;

        # show_state($stream, "line $ln");

        ok xnor( $is_first, $stream->is_first ), "is_first on line $ln";
        ok xnor( $is_last,  $stream->is_last ),  "is_last on line $ln";
    }
    ok !$stream->next, 'finished ok';

    if ( $lines == 0.5 ) {

        # This reflects current behaviour - not sure if it's right
        # though.
        ok $stream->is_first, 'is_first false before loop';
        ok !$stream->is_last, 'is_last false before loop';
    }
    else {
        ok !$stream->is_first, 'is_first false before loop';
        ok $stream->is_last, 'is_last false before loop';
    }

    # show_state($stream, 'after loop');
}
