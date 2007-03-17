use strict;
use warnings;
use Test::More;
use Data::Dumper;

use TAP::Parser::YAMLish;

my @SCHEDULE;

BEGIN {
    @SCHEDULE = (
        {   name => 'Hello World',
            in   => [
                '--- Hello, World',
                '...',
            ],
            out => "Hello, World",
        },
        {   name => 'Hello World 2',
            in   => [
                '--- \'Hello, \'\'World\'',
                '...',
            ],
            out => "Hello, 'World",
        },
        {   name => 'Hello World 3',
            in   => [
                '--- "Hello, World"',
                '...',
            ],
            out => "Hello, World",
        },
        {   name => 'Hello World 4',
            in   => [
                '--- "Hello, World"',
                '...',
            ],
            out => "Hello, World",
        },
        {   name => 'Hello World 4',
            in   => [
                '--- >',
                '   Hello,',
                '      World',
                '...',
            ],
            out => "Hello, World\n",
        },
        {   name => 'Hello World 5',
            in   => [
                '--- >',
                '   Hello,',
                '  World',
                '...',
            ],
            error => qr{Missing\s+'[.][.][.]'},
        },
        {   name => 'Simple array',
            in   => [
                '---',
                '- 1',
                '- 2',
                '- 3',
                '...',
            ],
            out => [ '1', '2', '3' ],
        },
        {   name => 'Mixed array',
            in   => [
                '---',
                '- 1',
                '- \'two\'',
                '- "three\n"',
                '...',
            ],
            out => [ '1', 'two', "three\n" ],
        },
        {   name => 'Hash in array',
            in   => [
                '---',
                '- 1',
                '- two: 2',
                '- 3',
                '...',
            ],
            out => [ '1', { two => '2' }, '3' ],
        },
        {   name => 'Hash in array 2',
            in   => [
                '---',
                '- 1',
                '- two: 2',
                '  three: 3',
                '- 4',
                '...',
            ],
            out => [ '1', { two => '2', three => '3' }, '4' ],
        },
        {   name => 'Nested array',
            in   => [
                '---',
                '- one',
                '-',
                '  - two',
                '  -',
                '    - three',
                '  - four',
                '- five',
                '...',
            ],
            out => [ 'one', [ 'two', ['three'], 'four' ], 'five' ],
        },
        {   name => 'Nested hash',
            in   => [
                '---',
                'one:',
                '  five: 5',
                '  two:',
                '    four: 4',
                '    three: 3',
                'six: 6',
                '...',
            ],
            out => {
                one => { two => { three => '3', four => '4' }, five => '5' },
                six => '6'
            },
        },

        {   name => 'Original YAML::Tiny test',
            in   => [
                '---',
                'invoice: 34843',
                'date   : 2001-01-23',
                'bill-to:',
                '    given  : Chris',
                '    family : Dumars',
                '    address:',
                '        lines: |',
                '            458 Walkman Dr.',
                '            Suite #292',
                '        city    : Royal Oak',
                '        state   : MI',
                '        postal  : 48046',
                'product:',
                '    - sku         : BL394D',
                '      quantity    : 4',
                '      description : Basketball',
                '      price       : 450.00',
                '    - sku         : BL4438H',
                '      quantity    : 1',
                '      description : Super Hoop',
                '      price       : 2392.00',
                'tax  : 251.42',
                'total: 4443.52',
                'comments: >',
                '    Late afternoon is best.',
                '    Backup contact is Nancy',
                '    Billsmer @ 338-4338',
                '...',
            ],
            out => {
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
            }
        },

    );

    plan tests => @SCHEDULE * 4;
}

sub iter {
    my $ar = shift;
    return sub {
        return shift @$ar;
    };
}

for my $test (@SCHEDULE) {
    my $name = $test->{name};
    ok my $yaml = TAP::Parser::YAMLish->new, "$name: Created";
    isa_ok $yaml, 'TAP::Parser::YAMLish';

    #     diag "$name\n";

    unless ( $test->{in} ) {
        pass for 1 .. 2;
        use YAML;
        diag "Input for test:\n";
        diag( Dump( $test->{out} ) );
        next;
    }

    # diag "Input:\n";
    # diag( Data::Dumper->Dump( [ $test->{in} ], ['$input'] ) );

    my $iter = iter( $test->{in} );
    my $got = eval { $yaml->read($iter) };
    if ( my $err = $test->{error} ) {
        unless ( like $@, $err, "$name: Error message" ) {
            diag "Error: $@\n";
        }
        ok !$got, "$name: No result";
    }
    else {
        my $want = $test->{out};
        unless ( ok !$@, "$name: No error" ) {
            diag "Error: $@\n";
        }
        unless ( is_deeply $got, $want, "$name: Result matches" ) {
            diag( Data::Dumper->Dump( [$got],  ['$got'] ) );
            diag( Data::Dumper->Dump( [$want], ['$expected'] ) );
        }
    }
}
