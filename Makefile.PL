use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;

eval 'use ExtUtils::MakeMaker::Coverage';
warn
  "\nOptional ExtUtils::MakeMaker::Coverage not available. Everything should\n",
  "still work correctly but you won't be able to run the coverage tests by\n",
  "typing \"make testcover\". If you subsequently install Devel::Cover please\n",
  "re-run \"perl Makefile.PL\" to include the testcover target.\n\n"
  if $@;

my @program;
if (prompt(
        "TAP::Parser includes \"runtests\" which is the equivalent of the\n"
          . "TAP::Harness \"prove\". If you choose to install runtests you will be able\n"
          . "to run a module's test suite via TAP::Parser by typing \"runtests -rb\" in\n"
          . "the project's root directory.\n\n"
          . "Do you wish to install the 'runtests' utility?", "y"
    ) =~ /^[Yy]/
  )
{
    @program = ( EXE_FILES => ["bin/runtests"] );
}

WriteMakefile(
    'NAME'         => 'TAP::Parser',
    'VERSION_FROM' => 'lib/TAP/Parser.pm',
    'PREREQ_PM'    => {
        'Test::More' => '0',
        'Pod::Usage' => '0',    # for 'runtests' utility
    },
    'INSTALLDIRS' => 'site',
    'PL_FILES'    => {},
    'LICENSE'     => 'perl',
    'test'        => { 'TESTS' => 't/*.t t/compat/*.t' },
    @program,
);
