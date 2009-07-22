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

use Test::More tests => 68;

use File::Spec;

use EmptyParser;
use TAP::Parser::SourceDetector;
use TAP::Parser::SourceDetector::Perl;
use TAP::Parser::SourceDetector::File;
use TAP::Parser::SourceDetector::RawTAP;

my $parser = EmptyParser->new;
my $dir    = File::Spec->catdir(
    (   $ENV{PERL_CORE}
        ? ( File::Spec->updir(), 'ext', 'Test-Harness' )
        : ()
    ),
    't',
    'source_tests'
);

my $perl = $^X;

# Abstract base class tests
{
    can_ok 'TAP::Parser::SourceDetector', 'new';
    my $source = TAP::Parser::SourceDetector->new;
    isa_ok $source, 'TAP::Parser::SourceDetector';

    can_ok $source, 'raw_source';
    is $source->raw_source('hello'), $source, '... can set';
    is $source->raw_source, 'hello', '... and get';

    # TODO: deprecated
    can_ok $source, 'source';
    is $source->source, 'hello', '... and get = raw_source';

    can_ok $source, 'merge';
    is $source->merge('hello'), $source, '... can set';
    is $source->merge, 'hello', '... and get';

    can_ok $source, 'config';
    is $source->config('hello'), $source, '... can set';
    is $source->config, 'hello', '... and get';

    can_ok $source, 'get_stream';
    eval { $source->get_stream($parser) };
    my $error = $@;
    like $error, qr/^Abstract method/,
      '... with an appropriate error message';
}

# Executable source tests
{
    my $test = File::Spec->catfile( $dir, 'source' );
    my $source = TAP::Parser::SourceDetector::Executable->new;
    isa_ok $source, 'TAP::Parser::SourceDetector::Executable';

    can_ok $source, 'source';
    eval { $source->source("$perl -It/lib $test") };
    ok my $error = $@, '... and calling it with a string should fail';
    like $error, qr/^Argument to &raw_source must be an array reference/,
      '... with an appropriate error message';
    ok $source->source( [ $perl, '-It/lib', '-T', $test ] ),
      '... and calling it with valid args should succeed';

    can_ok $source, 'get_stream';
    my $stream = $source->get_stream($parser);

    isa_ok $stream, 'TAP::Parser::Iterator::Process',
      'get_stream returns the right object';
    can_ok $stream, 'next';
    is $stream->next, '1..1', '... and the first line should be correct';
    is $stream->next, 'ok 1', '... as should the second';
    ok !$stream->next, '... and we should have no more results';
}

# Perl source tests
{
    my $test = File::Spec->catfile( $dir, 'source' );
    my $source = TAP::Parser::SourceDetector::Perl->new;
    isa_ok $source, 'TAP::Parser::SourceDetector::Perl',
      '... and the object it returns';

    can_ok $source, 'source';
    ok $source->source( [$test] ),
      '... and calling it with valid args should succeed';

    can_ok $source, 'get_stream';
    my $stream = $source->get_stream($parser);

    isa_ok $stream, 'TAP::Parser::Iterator::Process',
      '... and the object it returns';
    can_ok $stream, 'next';
    is $stream->next, '1..1', '... and the first line should be correct';
    is $stream->next, 'ok 1', '... as should the second';
    ok !$stream->next, '... and we should have no more results';

    # internals tests!
    can_ok $source, '_switches';
    ok( grep( $_ =~ /^['"]?-T['"]?$/, $source->_switches ),
        '... and it should find the taint switch'
    );
}

# coverage test for TAP::Parser::SourceDetector::Executable

{

    # coverage for method get_steam
    my $source
      = TAP::Parser::SourceDetector::Executable->new( { parser => $parser } );

    my @die;
    eval {
        local $SIG{__DIE__} = sub { push @die, @_ };
        $source->get_stream;
    };

    is @die, 1, 'coverage testing of Executable get_stream';
    like pop @die, qr/No command found!/, '...and it failed as expect';
}

# Raw TAP source tests
{
    my $source = TAP::Parser::SourceDetector::RawTAP->new;
    isa_ok $source, 'TAP::Parser::SourceDetector::RawTAP';

    can_ok $source, 'raw_source';
    eval { $source->raw_source("1..1\nok 1\n") };
    ok my $error = $@, '... and calling it with a string should fail';
    like $error,
      qr/^Argument to &raw_source must be a scalar or array reference/,
      '... with an appropriate error message';
    ok $source->raw_source( \"1..1\nok 1\n" ),
      '... and calling it with valid args should succeed';

    can_ok $source, 'get_stream';
    my $stream = $source->get_stream($parser);

    isa_ok $stream, 'TAP::Parser::Iterator::Array',
      'get_stream returns the right object';
    can_ok $stream, 'next';
    is $stream->next, '1..1', '... and the first line should be correct';
    is $stream->next, 'ok 1', '... as should the second';
    ok !$stream->next, '... and we should have no more results';
}

# Text file TAP source tests
{
    my $test = File::Spec->catfile( $dir, 'source.tap' );
    my $source = TAP::Parser::SourceDetector::File->new;
    isa_ok $source, 'TAP::Parser::SourceDetector::File';

    can_ok $source, 'raw_source';
    ok $source->raw_source( \$test ),
      '... and calling it with valid args should succeed';

    can_ok $source, 'get_stream';
    my $stream = $source->get_stream($parser);

    isa_ok $stream, 'TAP::Parser::Iterator::Stream',
      'get_stream returns the right object';
    can_ok $stream, 'next';
    is $stream->next, '1..1', '... and the first line should be correct';
    is $stream->next, 'ok 1', '... as should the second';
    ok !$stream->next, '... and we should have no more results';
}

# IO::Handle TAP source tests
{
    my $test = File::Spec->catfile( $dir, 'source.tap' );
    my $source = TAP::Parser::SourceDetector::File->new;
    isa_ok $source, 'TAP::Parser::SourceDetector::File';

    can_ok $source, 'raw_source';
    ok $source->raw_source( \$test ),
      '... and calling it with valid args should succeed';

    can_ok $source, 'get_stream';
    my $stream = $source->get_stream($parser);

    isa_ok $stream, 'TAP::Parser::Iterator::Stream',
      'get_stream returns the right object';
    can_ok $stream, 'next';
    is $stream->next, '1..1', '... and the first line should be correct';
    is $stream->next, 'ok 1', '... as should the second';
    ok !$stream->next, '... and we should have no more results';
}

