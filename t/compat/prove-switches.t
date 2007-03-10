BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use File::Spec;
use Test::More;
plan skip_all => "prove not available";
plan skip_all => "Not adapted to perl core" if $ENV{PERL_CORE};
plan skip_all => "Not installing prove" if -e "t/SKIP-PROVE";

# Work around a Cygwin bug.  Remove this if Perl bug 30952 ever gets fixed.
# http://rt.perl.org/rt3/Ticket/Display.html?id=30952.
plan skip_all => "Skipping because of a Cygwin bug" if ( $^O =~ /cygwin/i );

plan tests => 8;

my $blib      = File::Spec->catfile( File::Spec->curdir, "blib" );
my $blib_lib  = File::Spec->catfile( $blib,              "lib" );
my $blib_arch = File::Spec->catfile( $blib,              "arch" );
my $prove = File::Spec->catfile( $blib, "script", "prove" );
$prove = "$^X $prove";

CAPITAL_TAINT: {
    local $ENV{PROVE_SWITCHES};

    my @actual   = qx/$prove -Ifirst -D -I second -Ithird -Tvdb/;
    my @expected = (
        "# \$TAP::Harness::Compatible::Switches: -T -I$blib_arch -I$blib_lib -Ifirst -Isecond -Ithird\n"
    );
    is_deeply( \@actual, \@expected, "Capital taint flags OK" );
}

LOWERCASE_TAINT: {
    local $ENV{PROVE_SWITCHES};

    my @actual   = qx/$prove -dD -Ifirst -I second -t -Ithird -vb/;
    my @expected = (
        "# \$TAP::Harness::Compatible::Switches: -t -I$blib_arch -I$blib_lib -Ifirst -Isecond -Ithird\n"
    );
    is_deeply( \@actual, \@expected, "Lowercase taint OK" );
}

PROVE_SWITCHES: {
    local $ENV{PROVE_SWITCHES} = "-dvb -I fark";

    my @actual   = qx/$prove -Ibork -Dd/;
    my @expected = (
        "# \$TAP::Harness::Compatible::Switches: -I$blib_arch -I$blib_lib -Ifark -Ibork\n"
    );
    is_deeply( \@actual, \@expected, "PROVE_SWITCHES OK" );
}

PROVE_SWITCHES_L: {
    my @actual = qx/$prove -l -Ibongo -Dd/;
    my @expected
      = ("# \$TAP::Harness::Compatible::Switches: -Ilib -Ibongo\n");
    is_deeply( \@actual, \@expected, "PROVE_SWITCHES OK" );
}

PROVE_SWITCHES_LB: {
    my @actual   = qx/$prove -lb -Dd/;
    my @expected = (
        "# \$TAP::Harness::Compatible::Switches: -Ilib -I$blib_arch -I$blib_lib\n"
    );
    is_deeply( \@actual, \@expected, "PROVE_SWITCHES OK" );
}

PROVE_VERSION: {

# This also checks that the prove $VERSION is in sync with TAP::Harness::Compatible's $VERSION
    local $/ = undef;

    use_ok('TAP::Harness::Compatible');

    my $thv    = $TAP::Harness::Compatible::VERSION;
    my @actual = qx/$prove --version/;
    is( scalar @actual, 1, 'Only 1 line returned' );
    like(
        $actual[0],
        qq{/^\Qprove v$thv, using TAP::Harness::Compatible v$thv and Perl v5\E/}
    );
}
