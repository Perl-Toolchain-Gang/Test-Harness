#!/usr/bin/perl -wT

use strict;

#use Test::More 'no_plan';
use Test::More tests => 52;
use TAPx::Parser;

use TAPx::Parser::Iterator;

sub array_ref_from {
    my $string = shift;
    my @lines = split /\n/ => $string;
    return \@lines;
}

# we slurp __DATA__ and then reset it so we don't have to duplicate our TAP
my $offset = tell DATA;
my $tap = do { local $/; <DATA> };
seek DATA, $offset, 0;

foreach my $source ( array_ref_from($tap), \*DATA ) {
    ok my $iter = TAPx::Parser::Iterator->new($source),
      'We should be able to create a new iterator';
    isa_ok $iter, 'TAPx::Parser::Iterator', '... and the object it returns';
    my $subclass =
        'ARRAY' eq ref $source
      ? 'TAPx::Parser::Iterator::ARRAY'
      : 'TAPx::Parser::Iterator::FH';
    isa_ok $iter, , $subclass, '... and the object it returns';

    can_ok $iter, 'is_first';
    can_ok $iter, 'is_last';

    foreach my $method (qw<is_first is_last>) {
        ok !$iter->$method,
          "... $method() should not return true for a new iter";
    }

    can_ok $iter, 'exit';
    ok !defined $iter->exit, '... and it should be undef before we are done';

    can_ok $iter, 'next';
    is $iter->next, 'one', 'next() should return the first result';
    ok $iter->is_first, '... and is_first() should now return true';
    ok !$iter->is_last, '... and is_last() should now return false';

    is $iter->next, 'two', 'next() should return the second result';
    ok !$iter->is_first, '... and is_first() should now return false';
    ok !$iter->is_last,  '... and is_last() should now return false';

    is $iter->next, '', 'next() should return the third result';
    ok !$iter->is_first, '... and is_first() should now return false';
    ok !$iter->is_last,  '... and is_last() should now return false';

    is $iter->next, 'three', 'next() should return the fourth result';
    ok !$iter->is_first, '... and is_first() should now return false';
    ok $iter->is_last, '... and is_last() should now return true';

    ok !defined $iter->next, 'next() should return undef after it is empty';
    ok !$iter->is_first, '... and is_first() should now return false';
    ok $iter->is_last, '... and is_last() should now return true';

    is $iter->exit, 0, '... and exit should now return 0';
}

__DATA__
one
two

three
