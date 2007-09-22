#!/usr/bin/perl -w

use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;

my $Have_Testcover = eval {
    require ExtUtils::MakeMaker::Coverage;
    ExtUtils::MakeMaker::Coverage->import;
    1;
};

my %mm_args = (
    'NAME'         => 'Test::Harness',
    'VERSION_FROM' => 'lib/Test/Harness.pm',
    'PREREQ_PM'    => {
        'File::Spec' => 0.8,
    },
    'INSTALLDIRS' => 'perl',
    'PL_FILES'    => {},
    'test'        => { 'TESTS' => 't/*.t t/compat/*.t' },
    'EXE_FILES'   => ['bin/prove'],
);

if ( $ExtUtils::MakeMaker::VERSION >= 6.31 ) {
    $mm_args{LICENSE} = 'perl';
}
WriteMakefile( %mm_args );

{
    package MY;

    sub postamble {
        if( $Have_Testcover ) {
            return testcover();
        }
        else {
            return q[
testcover :
	$(NOECHO) $(ECHO) To enable testcover, install ExtUtils::MakeMaker::Coverage and rerun Makefile.PL.
];
        }
    }

    use File::Spec;
    use Config;

    sub test_via_harness {
        my ($self, $orig_perl, $tests) = @_;

        my $perl5lib = join $Config{path_sep},
                       grep { defined && length } 
                            File::Spec->canonpath('lib/'), $ENV{PERL5LIB};

        my $perl = "PERL5LIB=$perl5lib $orig_perl";
        return $self->SUPER::test_via_harness($perl, $tests);
    }
}
