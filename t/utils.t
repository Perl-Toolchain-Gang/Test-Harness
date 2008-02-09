#!/usr/bin/perl -w

BEGIN {
    chdir 't' and @INC = '../lib' if $ENV{PERL_CORE};
}

use strict;
use lib 't/lib';

use TAP::Parser::Utils;
use Test::More;

my @schedule = (
    {   name => 'Bare words',
        in   => 'bare words are here',
        out  => [ 'bare', 'words', 'are', 'here' ],
    },
    {   name => 'Single quotes',
        in   => "'bare' 'words' 'are' 'here'",
        out  => [ 'bare', 'words', 'are', 'here' ],
    },
    {   name => 'Double quotes',
        in   => '"bare" "words" "are" "here"',
        out  => [ 'bare', 'words', 'are', 'here' ],
    },
    {   name => 'Escapes',
        in   => '\  "ba\"re" \'wo\\\'rds\' \\\\"are" "here"',
        out  => [ ' ', 'ba"re', "wo'rds", '\\are', 'here' ],
    },
    {   name => 'Flag',
        in   => '-e "system(shift)"',
        out  => [ '-e', 'system(shift)' ],
    },
    {   name => 'Nada',
        in   => undef,
        out  => [],
    },
    {   name => 'Nada II',
        in   => '',
        out  => [],
    },
    {   name => 'Zero',
        in   => 0,
        out  => ['0'],
    }
);

plan tests => 1 * @schedule;

for my $test (@schedule) {
    my $name = $test->{name};
    my @got  = TAP::Parser::Utils::split_shell_switches( $test->{in} );
    unless ( is_deeply \@got, $test->{out}, "$name: parse OK" ) {
        use Data::Dumper;
        diag( Dumper( { want => $test->{out}, got => \@got } ) );
    }
}
