#!/usr/bin/perl -w

use strict;

#use Test::More 'no_plan';
use Test::More tests => 39;
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

my @schedule = (
    'TAP::Parser::Iterator::Array',
    array_ref_from($tap),
    'TAP::Parser::Iterator::Stream',
    \*DATA,
    'TAP::Parser::Iterator::Process',
    { command => [ $^X, '-e', 'print qq/one\ntwo\n\nthree\n/' ] },
);

while ( my ( $subclass, $source ) = splice @schedule, 0, 2 ) {
    ok my $iter = TAP::Parser::Iterator->new($source),
      'We should be able to create a new iterator';
    isa_ok $iter, 'TAP::Parser::Iterator', '... and the object it returns';
    isa_ok $iter, $subclass, '... and the object it returns';

    can_ok $iter, 'exit';
    ok !defined $iter->exit,
      "... and it should be undef before we are done ($subclass)";

    can_ok $iter, 'next';
    is $iter->next, 'one', 'next() should return the first result';

    is $iter->next, 'two', 'next() should return the second result';

    is $iter->next, '', 'next() should return the third result';

    is $iter->next, 'three', 'next() should return the fourth result';

    ok !defined $iter->next, 'next() should return undef after it is empty';

    is $iter->exit, 0, "... and exit should now return 0 ($subclass)";

    is $iter->wait, 0, "wait should also now return 0 ($subclass)";
}

__DATA__
one
two

three
