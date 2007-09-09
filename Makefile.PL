#!/usr/bin/perl -w

use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;

my $Have_Testcover = eval {
    require ExtUtils::MakeMaker::Coverage;
    ExtUtils::MakeMaker::Coverage->import;
    1;
};

WriteMakefile(
    'NAME'         => 'Test::Harness',
    'VERSION_FROM' => 'lib/Test/Harness.pm',
    'PREREQ_PM'    => {
    },
    'INSTALLDIRS' => 'perl',
    'PL_FILES'    => {},
    ($ExtUtils::MakeMaker::VERSION <= 6.31 ? (LICENSE         => 'perl') : ()),
    'test'        => { 'TESTS' => 't/*.t t/compat/*.t' },
    'EXE_FILES'   => ["bin/prove"],
);

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
}