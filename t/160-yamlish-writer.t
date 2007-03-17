#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use TAP::Parser::YAMLish::Reader;
use TAP::Parser::YAMLish::Writer;

my @SCHEDULE;

BEGIN {
    @SCHEDULE = (
        {   name => 'Simple scalar',
            in   => 1,
            out  => [
                '--- 1',
                '...',
            ],
        },
        {   name => 'Undef',
            in   => undef,
            out  => [
                '--- ~',
                '...',
            ],
        },
        {   name => 'Unprintable',
            in   => "\x01\n\t",
            out  => [
                '--- "\x01\n\t"',
                '...',
            ],
        },
        {   name => 'Simple array',
            in   => [ 1, 2, 3 ],
            out  => [
                '---',
                '- 1',
                '- 2',
                '- 3',
                '...',
            ],
        },
        {   name => 'Array, two elements, undef',
            in   => [ undef, undef ],
            out  => [
                '---',
                '- ~',
                '- ~',
                '...',
            ],
        },
        {   name => 'Nested array',
            in   => [ 1, 2, [ 3, 4 ], 5 ],
            out  => [
                '---',
                '- 1',
                '- 2',
                '-',
                '  - 3',
                '  - 4',
                '- 5',
                '...',
            ],
        },
        {   name => 'Simple hash',
            in   => { one => '1', two => '2', three => '3' },
            out  => [
                '---',
                'one: 1',
                'three: 3',
                'two: 2',
                '...',
            ],
        },
        {   name => 'Nested hash',
            in   => {
                one => '1', two => '2', more => { three => '3', four => '4' }
            },
            out => [
                '---',
                'more:',
                '  four: 4',
                '  three: 3',
                'one: 1',
                'two: 2',
                '...',
            ],
        },
        {   name => 'Unprintable key',
            in   => { one => '1', "\x02" => '2', three => '3' },
            out  => [
                '---',
                '"\x02": 2',
                'one: 1',
                'three: 3',
                '...',
            ],
        },
        {   name => 'Complex',
            in   => {
                'bill-to' => {
                    'given'   => 'Chris',
                    'address' => {
                        'city'   => 'Royal Oak',
                        'postal' => '48046',
                        'lines'  => "458 Walkman Dr.\nSuite #292\n",
                        'state'  => 'MI'
                    },
                    'family' => 'Dumars'
                },
                'invoice' => '34843',
                'date'    => '2001-01-23',
                'tax'     => '251.42',
                'product' => [
                    {   'sku'         => 'BL394D',
                        'quantity'    => '4',
                        'price'       => '450.00',
                        'description' => 'Basketball'
                    },
                    {   'sku'         => 'BL4438H',
                        'quantity'    => '1',
                        'price'       => '2392.00',
                        'description' => 'Super Hoop'
                    }
                ],
                'comments' =>
                  "Late afternoon is best. Backup contact is Nancy Billsmer @ 338-4338\n",
                'total' => '4443.52'
            },
            out => [
                "---",
                "bill-to:",
                "  address:",
                "    city: \"Royal Oak\"",
                "    lines: \"458 Walkman Dr.\\nSuite #292\\n\"",
                "    postal: 48046",
                "    state: MI",
                "  family: Dumars",
                "  given: Chris",
                "comments: \"Late afternoon is best. Backup contact is Nancy Billsmer \@ 338-4338\\n\"",
                "date: 2001-01-23",
                "invoice: 34843",
                "product:",
                "  -",
                "    description: Basketball",
                "    price: 450.00",
                "    quantity: 4",
                "    sku: BL394D",
                "  -",
                "    description: \"Super Hoop\"",
                "    price: 2392.00",
                "    quantity: 1",
                "    sku: BL4438H",
                "tax: 251.42",
                "total: 4443.52",
                "...",
            ],
        },
    );

    plan tests => @SCHEDULE * 5;
}

sub iter {
    my $ar = shift;
    return sub {
        return shift @$ar;
    };
}

for my $test (@SCHEDULE) {
    my $name = $test->{name};
    ok my $yaml = TAP::Parser::YAMLish::Writer->new, "$name: Created";
    isa_ok $yaml, 'TAP::Parser::YAMLish::Writer';

    my $got = [];
    my $writer = sub { push @$got, shift };

    my $data = $test->{in};

    eval { $yaml->write( $data, $writer ) };

    if ( my $err = $test->{error} ) {
        unless ( like $@, $err, "$name: Error message" ) {
            diag "Error: $@\n";
        }
        is_deeply $got, [], "$name: No result";
        pass;
    }
    else {
        my $want = $test->{out};
        unless ( ok !$@, "$name: No error" ) {
            diag "Error: $@\n";
        }
        unless ( is_deeply $got, $want, "$name: Result matches" ) {
            local $Data::Dumper::Useqq = $Data::Dumper::Useqq = 1;
            diag( Data::Dumper->Dump( [$got],  ['$got'] ) );
            diag( Data::Dumper->Dump( [$want], ['$expected'] ) );
        }

        my $yr = TAP::Parser::YAMLish::Reader->new;

        # Now try parsing it
        my $reader = sub { shift @$got };
        my $parsed = $yr->read($reader);

        unless ( is_deeply $parsed, $data, "$name: Reparse OK" ) {
            local $Data::Dumper::Useqq = $Data::Dumper::Useqq = 1;
            diag( Data::Dumper->Dump( [$parsed], ['$parsed'] ) );
            diag( Data::Dumper->Dump( [$data],   ['$data'] ) );
        }
    }
}

