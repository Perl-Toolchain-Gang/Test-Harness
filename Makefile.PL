#!/usr/bin/perl -w

# This Makefile.PL is provided for installation compatibility.
# Extra developer actions are in the Build.PL.

use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;

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
WriteMakefile(%mm_args);
