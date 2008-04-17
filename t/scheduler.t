#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More tests => 1;
use TAP::Parser::Scheduler;

my $rules = {
    par => [
        { seq => '../ext/DB_File/t/*' },
        { seq => '../ext/IO_Compress_Zlib/t/*' },
        { seq => '../lib/CPANPLUS/*' },
        { seq => '../lib/ExtUtils/t/*' },
        '*'
    ]
};

my $tests = [
    '../ext/DB_File/t/A',
    'foo',
    '../ext/DB_File/t/B',
    '../ext/DB_File/t/C',
    '../lib/CPANPLUS/D',
    '../lib/CPANPLUS/E',
    'bar',
    '../lib/CPANPLUS/F',
];

ok my $scheduler = TAP::Parser::Scheduler->new(
    tests => $tests,
    rules => $rules,
  ),
  'new';

# while ( defined( my $job = $scheduler->get_job ) ) {
#     diag $job->filename;
# }

# use Data::Dumper;
# diag( Dumper($scheduler) );

# diag( $_ ) for map { $_->filename } $scheduler->get_all;

# diag( Dumper( [ $scheduler->get_all ] ) );
