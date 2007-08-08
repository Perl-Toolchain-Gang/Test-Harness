use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;

eval 'use ExtUtils::MakeMaker::Coverage';
warn "Optional ExtUtils::MakeMaker::Coverage not available\n" if $@;

my @program;
if (
    prompt( "Do you wish to install the 'runtests' utility?", "y" ) =~ /^[Yy]/ )
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
