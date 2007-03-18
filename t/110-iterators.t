#!/usr/bin/perl -w

use strict;

#use Test::More 'no_plan';
use Test::More tests => 54;
use File::Spec;
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

my $did_setup    = 0;
my $did_teardown = 0;

my $setup    = sub { $did_setup++ };
my $teardown = sub { $did_teardown++ };

my @schedule = (
    {   subclass => 'TAP::Parser::Iterator::Array',
        source   => array_ref_from($tap),
    },
    {   subclass => 'TAP::Parser::Iterator::Stream',
        source   => \*DATA,
    },
    {   subclass => 'TAP::Parser::Iterator::Process',
        source =>
          { command => [ $^X, '-e', 'print qq/one\ntwo\n\nthree\n/' ] },
    },
    {   subclass => 'TAP::Parser::Iterator::Process',
        source   => {
            command => [
                $^X, File::Spec->catfile( 't', 'sample-tests', 'out_err_mix' )
            ],
            merge    => 1,
            setup    => $setup,
            teardown => $teardown,
        },
        after => sub {
            is $did_setup,    1, "setup called";
            is $did_teardown, 1, "teardown called";
          }
    },
);

for my $test (@schedule) {
    my $subclass = $test->{subclass};
    my $source   = $test->{source};
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

    if ( my $after = $test->{after} ) {
        $after->();
    }
}

__DATA__
one
two

three
