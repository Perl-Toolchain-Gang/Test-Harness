#!perl
use strict;
use lib 't/lib';
use strict;
use warnings;
use Test::More tests => 2;
use File::Spec;
use TAP::Harness;

{

    # Test that t/sample-tests/switches fails when there's a module
    # load PERL5OPT

    local $ENV{PERL5OPT} = '-Mstrict';
    my $h = TAP::Harness->new;
    my $ag
      = $h->runtests(
        map { [ File::Spec->catfile( 't', 'sample-tests', $_ ), $_ ] }
          qw( switches is_strict ) );
    is $ag->total, 2, 'two tests enter...';
    my @failed = $ag->failed;
    is_deeply \@failed, ['switches'], '...only one leaves';
}
