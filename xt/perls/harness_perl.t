#!/usr/bin/perl

use warnings;
use strict;

use Test::More skip_all => '"foreign perl" test setup not decided';

# TODO we need to have some way to find one or more alternate versions
# of perl on the smoke machine so that we can verify that the installed
# perl can be used to test against the alternate perls without
# installing the harness in the alternate perls.  Does that make sense?
#
# Example:
#  harness process (i.e. bin/prove) is perl 5.8.8.
#  subprocesses    (i.e. t/test.t) are perl 5.6.2.

my $perl = '/usr/local/stow/perl-5.6.2/bin/perl';
# system("HARNESS_PERL=$perl perl -Ilib bin/prove -Ilib -r t")

# vim:ts=4:sw=4:et:sta
