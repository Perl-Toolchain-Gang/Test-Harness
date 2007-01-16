#!/usr/bin/perl -w

use strict;

use lib 'lib';

use Test::More tests => 28;
use TAPx::Parser::Source;
use TAPx::Parser::Source::Perl;

chdir 't' if -d 't';
my $test = 'source_tests/source';

my $perl = $^X;

can_ok 'TAPx::Parser::Source', 'new';
ok my $source = TAPx::Parser::Source->new,
  '... and calling it should succeed';
isa_ok $source, 'TAPx::Parser::Source', '... and the object it returns';

can_ok $source, 'source';
eval { $source->source("$perl $test") };
ok my $error = $@, '... and calling it with a string should fail';
like $error, qr/^Argument to &source must be an array reference/,
  '... with an appropriate error message';
ok $source->source( [ $perl, '-T', $test ] ),
  '... and calling it with valid args should succeed';

can_ok $source, 'get_stream';
ok my $stream = $source->get_stream, '... and calling it should succeed';

isa_ok $stream, 'TAPx::Parser::Iterator', '... and the object it returns';
can_ok $stream, 'next';
is $stream->next, '1..1', '... and the first line should be correct';
is $stream->next, 'ok 1', '... as should the second';
ok !$stream->next, '... and we should have no more results';

can_ok 'TAPx::Parser::Source::Perl', 'new';
ok $source = TAPx::Parser::Source::Perl->new,
  '... and calling it should succeed';
isa_ok $source, 'TAPx::Parser::Source::Perl', '... and the object it returns';

can_ok $source, 'source';
ok $source->source( $test ),
  '... and calling it with valid args should succeed';

can_ok $source, 'get_stream';
ok $stream = $source->get_stream, '... and calling it should succeed';

isa_ok $stream, 'TAPx::Parser::Iterator', '... and the object it returns';
can_ok $stream, 'next';
is $stream->next, '1..1', '... and the first line should be correct';
is $stream->next, 'ok 1', '... as should the second';
ok !$stream->next, '... and we should have no more results';


# internals tests!

can_ok $source, '_switches';
ok grep({ $_ eq '-T' } $source->_switches),
     '... and it should find the taint switch';
