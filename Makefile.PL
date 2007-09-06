use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;

eval 'use ExtUtils::MakeMaker::Coverage';
warn
  "\nOptional ExtUtils::MakeMaker::Coverage not available. Everything should\n",
  "still work correctly but you won't be able to run the coverage tests by\n",
  "typing \"make testcover\". If you subsequently install Devel::Cover please\n",
  "re-run \"perl Makefile.PL\" to include the testcover target.\n\n"
  if $@;

WriteMakefile(
    'NAME'         => 'Test::Harness',
    'VERSION_FROM' => 'lib/Test/Harness.pm',
    'PREREQ_PM'    => {
    },
    'INSTALLDIRS' => 'site',
    'PL_FILES'    => {},
    ($ExtUtils::MakeMaker::VERSION <= 6.31 ? (LICENSE         => 'perl') : ()),
    'test'        => { 'TESTS' => 't/*.t t/compat/*.t' },
    'EXE_FILES'   => ["bin/prove"],
);

