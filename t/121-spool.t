#!/usr/bin/perl -w

# test T::H::_open_spool and _close_spool - these are good examples
# of the 'Fragile Test' pattern - messing with I/O primitives breaks
# nearly everything

use strict;
use lib 't/lib';

use Test::More;

my $useOrigOpen;
my $useOrigClose;

# setup replacements for core open and close - breaking these makes everything very fragile
BEGIN {
    $useOrigOpen = $useOrigClose = 1;

    # taken from http://www.perl.com/pub/a/2002/06/11/threads.html?page=2

    *CORE::GLOBAL::open = \&my_open;

    sub my_open (*@) {
        if ($useOrigOpen) {
            if ( defined( $_[0] ) ) {
                use Symbol qw();
                my $handle = Symbol::qualify( $_[0], (caller)[0] );
                no strict 'refs';
                if ( @_ == 1 ) {
                    return CORE::open($handle);
                }
                elsif ( @_ == 2 ) {
                    return CORE::open( $handle, $_[1] );
                }
                else {
                    return CORE::open( $handle, $_[1], @_[ 2 .. $#_ ] );
                }
            }
        }
        else {
            return;
        }
    }

    *CORE::GLOBAL::close = sub (*) {
        if   ($useOrigClose) { return CORE::close(shift) }
        else                 {return}
    };

}

# eval "require TAP::Harness";

use TAP::Harness;

plan tests => 2;

{

    # coverage tests for the basically untested T::H::_open_spool

    $ENV{PERL_TEST_HARNESS_DUMP_TAP} = File::Spec->catfile(qw(t spool));

# now given that we're going to be writing stuff to the file system, make sure we have
# a cleanup hook

    END {
        use File::Path;

        $useOrigOpen = $useOrigClose = 1;

        # remove the tree if we made it this far
        rmtree( $ENV{PERL_TEST_HARNESS_DUMP_TAP} )
          if $ENV{PERL_TEST_HARNESS_DUMP_TAP};
    }

    my @die;

    eval {
        local $SIG{__DIE__} = sub { push @die, @_ };

        # use the broken open
        $useOrigOpen = 0;

        TAP::Harness->_open_spool(
            File::Spec->catfile(qw (source_tests harness )) );

        # restore universal sanity
        $useOrigOpen = 1;
    };

    is @die, 1, 'open failed, die as expected';

    my $spool = File::Spec->catfile(qw(t spool source_tests harness));

    like pop @die, qr/ Can't write $spool [(] /, '...with expected message';

    # TODO do the close coverage, but we need to create a parser as well
}
