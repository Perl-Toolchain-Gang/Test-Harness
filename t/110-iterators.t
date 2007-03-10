#!/usr/bin/perl -wT

use strict;

#use Test::More 'no_plan';
use Test::More tests => 24;
use TAP::Parser;

use TAP::Parser::Iterator;

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
    ok my $iter = TAP::Parser::Iterator->new($source),
      'We should be able to create a new iterator';
    isa_ok $iter, 'TAP::Parser::Iterator', '... and the object it returns';
    my $subclass =
        'ARRAY' eq ref $source
      ? 'TAP::Parser::Iterator::ARRAY'
      : 'TAP::Parser::Iterator::FH';
    isa_ok $iter,, $subclass, '... and the object it returns';

    can_ok $iter, 'exit';
    ok !defined $iter->exit, '... and it should be undef before we are done';

    can_ok $iter, 'next';
    is $iter->next, 'one', 'next() should return the first result';

    is $iter->next, 'two', 'next() should return the second result';

    is $iter->next, '', 'next() should return the third result';

    is $iter->next, 'three', 'next() should return the fourth result';

    ok !defined $iter->next, 'next() should return undef after it is empty';

    is $iter->exit, 0, '... and exit should now return 0';
}

__DATA__
one
two

three
