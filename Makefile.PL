#!perl

require 5.006;

# This Makefile.PL is provided for installation compatibility.
# Extra developer actions are in the Build.PL.

use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;
use warnings;

my %mm_args = (
    'NAME'         => 'Test::Harness',
    'VERSION_FROM' => 'lib/Test/Harness.pm',
    'INSTALLDIRS'  => ($] < 5.011 ? 'perl' : 'site'),
    'PL_FILES'     => {},
    'test' => { 'TESTS' => 't/*.t t/compat/*.t' },

    'EXE_FILES'    => ['bin/prove'],
    'PREREQ_PM'    => {},
    'META_MERGE'   => {
        resources => {
            homepage   => 'http://testanything.org/',
            bugtracker => 'http://rt.cpan.org/Public/Dist/Display.html?Name=Test-Harness',

#           MailingList => 'mailto:<tapx-dev@hexten.net>',
            repository => 'http://github.com/Perl-Toolchain-Gang/Test-Harness/tree/master',
        },
        keywords   => [ 'TAP', 'test', 'harness', 'prove' ],
        recommends => {
            'Pod::Usage' => '1.12',    # for 'prove'
        },
    },
);

{
	no warnings;
    if ( $ExtUtils::MakeMaker::VERSION >= '6.31' ) {
        $mm_args{LICENSE} = 'perl';
    }
}

WriteMakefile(%mm_args);

package MY;

# Lifted from MM_Any.pm and modified so that make test tests against our
# own code rather than the incumbent. If we don't do this we end up
# loading a confused mixture of installed and new modules.
sub test_via_harness {
    my ( $self, $perl, $tests ) = @_;

    return $self->SUPER::test_via_harness(
        qq{$perl "-I\$(INST_LIB)" "-I\$(INST_ARCHLIB)"}, $tests );
}

sub postamble {
	return <<"END";
testprove: pure_all
	$^X -Iblib/lib bin/prove -b -r t

testleaks: pure_all
	$^X -MDevel::Leak::Object=GLOBAL_bless -Iblib/lib bin/prove -b -r t

testreference: pure_all
	$^X -Ireference/Test-Harness-2.64/lib reference/Test-Harness-2.64/bin/prove -Iblib/lib -r t

testauthor: pure_all
	$^X -Iblib/lib bin/prove -b -r xt

critic:
	perlcritic -1 -q -profile perlcriticrc bin/prove lib/ t/*.t

tags:
	ctags -f tags --recurse --totals --exclude=blib --exclude=.git --exclude='*~' --languages=Perl t/ lib/ bin/prove

tidy:
	(find lib t -name *.pm; find t -name *.t; echo Makefile.PL; echo bin/prove) | while read a; do perltidy -b \$\$a && rm \$\$a.bak; done;
END
}
