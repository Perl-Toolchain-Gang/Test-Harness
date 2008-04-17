#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More;
use TAP::Parser::Scheduler;

my $perl_rules = {
    par => [
        { seq => '../ext/DB_File/t/*' },
        { seq => '../ext/IO_Compress_Zlib/t/*' },
        { seq => '../lib/CPANPLUS/*' },
        { seq => '../lib/ExtUtils/t/*' },
        '*'
    ]
};

my $incomplete_rules = { par => [ { seq => [ '*A', '*D' ] } ] };

my $some_tests = [
    '../ext/DB_File/t/A',
    'foo',
    '../ext/DB_File/t/B',
    '../ext/DB_File/t/C',
    '../lib/CPANPLUS/D',
    '../lib/CPANPLUS/E',
    'bar',
    '../lib/CPANPLUS/F',
    '../ext/DB_File/t/D',
    '../ext/DB_File/t/E',
    '../ext/DB_File/t/F',
];

my @schedule = (
    {   name  => 'Sequential, no rules',
        tests => $some_tests,
        jobs  => 1,
    },
    {   name  => 'Sequential, Perl rules',
        rules => $perl_rules,
        tests => $some_tests,
        jobs  => 1,
    },
    {   name  => 'Two in parallel, Perl rules',
        rules => $perl_rules,
        tests => $some_tests,
        jobs  => 2,
    },
    {   name  => 'Massively parallel, Perl rules',
        rules => $perl_rules,
        tests => $some_tests,
        jobs  => 1000,
    },
    {   name  => 'Massively parallel, no rules',
        tests => $some_tests,
        jobs  => 1000,
    },
    {   name  => 'Sequential, incomplete rules',
        rules => $incomplete_rules,
        tests => $some_tests,
        jobs  => 1,
    },
    {   name  => 'Two in parallel, incomplete rules',
        rules => $incomplete_rules,
        tests => $some_tests,
        jobs  => 2,
    },
    {   name  => 'Massively parallel, incomplete rules',
        rules => $incomplete_rules,
        tests => $some_tests,
        jobs  => 1000,
    },
);

plan tests => @schedule * 2;

for my $test (@schedule) {
    test_scheduler(
        $test->{name},
        $test->{tests},
        $test->{rules},
        $test->{jobs}
    );
}

sub test_scheduler {
    my ( $name, $tests, $rules, $jobs ) = @_;

    ok my $scheduler = TAP::Parser::Scheduler->new(
        tests => $tests,
        defined $rules ? ( rules => $rules ) : (),
      ),
      "$name: new";

    # diag $scheduler->as_string;

    my @pipeline = ();
    my @got      = ();

    while ( defined( my $job = $scheduler->get_job ) ) {

        # diag $scheduler->as_string;
        if ( $job->is_spinner || @pipeline >= $jobs ) {
            die "Oops! Spinner!" unless @pipeline;
            my $done = shift @pipeline;
            $done->finish;

            # diag "Completed ", $done->filename;
        }
        next if $job->is_spinner;

        # diag "      Got ", $job->filename;
        push @pipeline, $job;

        push @got, $job->filename;
    }

    is_deeply [ sort @got ], [ sort @$tests ], "$name: got all tests";
}
