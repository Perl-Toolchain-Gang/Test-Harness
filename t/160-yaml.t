#!/usr/bin/perl -w

# Testing of basic document structures

use strict;
use File::Spec::Functions ':ALL';

BEGIN {
    $| = 1;
}

use lib catdir( 't', 'lib' );
use Test::More tests => 221;
use TAPx::Parser::YAML;

# Do we have the authorative YAML to test against
eval { require YAML; };
my $COMPARE_YAML = !!$YAML::VERSION;

# Do we have YAML::Syck to test against?
eval { require YAML::Syck; };
my $COMPARE_SYCK = !!$YAML::Syck::VERSION;

$SIG{__DIE__} = sub {
    require Carp;
    Carp::confess(@_);
};
my $sample_yaml = catfile(qw< t data sample.yml >);
ok my $data = TAPx::Parser::YAML->read($sample_yaml),
  'Reading YAML should succeed';
my $expected = [
    {   'bill-to' => {
            'given'   => 'Chris',
            'address' => {
                'city'   => 'Royal Oak',
                'postal' => '48046',
                'lines'  => '458 Walkman Dr.
Suite #292
',
                'state' => 'MI'
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
          'Late afternoon is best. Backup contact is Nancy Billsmer @ 338-4338
',
        'total' => '4443.52'
    }
];
is_deeply [@$data], $expected, '... and we should be able to read YAML';

my $out_yaml = catfile(qw< t data out.yml >);
ok $data->write($out_yaml), '... and writing the data should succeed';
ok my $data2 = TAPx::Parser::YAML->read($out_yaml),
  '... and we shoudl be able to read the new yaml';
is_deeply $data, $data2, '... and it should be unchanged';

END { unlink $out_yaml or die "Cannot unlink $out_yaml: $!" }

#####################################################################
# Sample Testing

# Test a completely empty document
yaml_ok(
    '',
    [],
    'empty',
);

# Just a newline
### YAML.pm has a bug where it dies on a single newline
yaml_ok(
    "\n\n",
    [],
    'only_newlines',
);

# Just a comment
yaml_ok(
    "# comment\n",
    [],
    'only_comment',
);

# Empty documents
yaml_ok(
    "---\n",
    [undef],
    'only_header',
);
yaml_ok(
    "---\n---\n",
    [ undef, undef ],
    'two_header',
);
yaml_ok(
    "--- ~\n",
    [undef],
    'one_undef',
);
yaml_ok(
    "---  ~\n",
    [undef],
    'one_undef2',
);
yaml_ok(
    "--- ~\n---\n",
    [ undef, undef ],
    'two_undef',
);

# Just a scalar
yaml_ok(
    "--- foo\n",
    ['foo'],
    'one_scalar',
);
yaml_ok(
    "---  foo\n",
    ['foo'],
    'one_scalar2',
);
yaml_ok(
    "--- foo\n--- bar\n",
    [ 'foo', 'bar' ],
    'two_scalar',
);

# Simple lists
yaml_ok(
    "---\n- foo\n",
    [ ['foo'] ],
    'one_list1',
);
yaml_ok(
    "---\n- foo\n- bar\n",
    [ [ 'foo', 'bar' ] ],
    'one_list2',
);
yaml_ok(
    "---\n- ~\n- bar\n",
    [ [ undef, 'bar' ] ],
    'one_listundef',
);

# Simple hashs
yaml_ok(
    "---\nfoo: bar\n",
    [ { foo => 'bar' } ],
    'one_hash1',
);

yaml_ok(
    "---\nfoo: bar\nthis: ~\n",
    [ { this => undef, foo => 'bar' } ],
    'one_hash2',
);

# Simple array inside a hash with an undef
yaml_ok(
    <<'END_YAML',
---
foo:
  - bar
  - ~
  - baz
END_YAML
    [ { foo => [ 'bar', undef, 'baz' ] } ],
    'array_in_hash',
);

# Simple hash inside a hash with an undef
yaml_ok(
    <<'END_YAML',
---
foo: ~
bar:
  foo: bar
END_YAML
    [ { foo => undef, bar => { foo => 'bar' } } ],
    'hash_in_hash',
);

# Mixed hash and scalars inside an array
yaml_ok(
    <<'END_YAML',
---
-
  foo: ~
  this: that
- foo
- ~
-
  foo: bar
  this: that
END_YAML
    [   [   { foo => undef, this => 'that' },
            'foo',
            undef,
            { foo => 'bar', this => 'that' },
        ]
    ],
    'hash_in_array',
);

# Simple single quote
yaml_ok(
    "---\n- 'foo'\n",
    [ ['foo'] ],
    'single_quote1',
);
yaml_ok(
    "---\n- '  '\n",
    [ ['  '] ],
    'single_spaces',
);
yaml_ok(
    "---\n- ''\n",
    [ [''] ],
    'single_null',
);

# Double quotes
yaml_ok(
    "--- \"  \"\n",
    ['  '],
    "only_spaces",
    noyaml => 1,
);

yaml_ok(
    "--- \"  foo\"\n--- \"bar  \"\n",
    [ "  foo", "bar  " ],
    "leading_trailing_spaces",
    noyaml => 1,
);

# Implicit document start
yaml_ok(
    "foo: bar\n",
    [ { foo => 'bar' } ],
    'implicit_hash',
);
yaml_ok(
    "- foo\n",
    [ ['foo'] ],
    'implicit_array',
);

# Inline nested hash
yaml_ok(
    <<'END_YAML',
---
- ~
- foo: bar
  this: that
- baz
END_YAML
    [ [ undef, { foo => 'bar', this => 'that' }, 'baz' ] ],
    'inline_nested_hash',
);

sub yaml_ok {
    my $string = shift;
    my $object = shift;
    my $name   = shift || 'unnamed';
    bless $object, 'TAPx::Parser::YAML';
    my %options = (@_);

    # If YAML itself is available, test with it first
    # Does the string parse to the structure
    my $yaml = eval { TAPx::Parser::YAML->read_string($string); };
    is( $@, '', "$name: TAPx::Parser::YAML parses without error" );
    SKIP: {
        skip( "Shortcutting after failure", 2 ) if $@;
        isa_ok( $yaml, 'TAPx::Parser::YAML' );
        is_deeply(
            $yaml, $object,
            "$name: TAPx::Parser::YAML parses correctly"
        );
    }

    # Does the structure serialize to the string.
    # We can't test this by direct comparison, because any
    # whitespace or comments would be lost.
    # So instead we parse back in.
    my $output = eval { $object->write_string };
    is( $@, '', "$name: TAPx::Parser::YAML serializes without error" );
    SKIP: {
        skip( "Shortcutting after failure", 4 ) if $@;
        ok( !!( defined $output and !ref $output ),
            "$name: TAPx::Parser::YAML serializes correctly",
        );
        my $roundtrip = eval { TAPx::Parser::YAML->read_string($output) };
        is( $@, '',
            "$name: TAPx::Parser::YAML round-trips without error"
        );
        skip( "Shortcutting after failure", 2 ) if $@;
        isa_ok( $roundtrip, 'TAPx::Parser::YAML' );
        is_deeply(
            $roundtrip, $object,
            "$name: TAPx::Parser::YAML round-trips correctly"
        );
    }

    # Return true as a convenience
    return 1;
}
