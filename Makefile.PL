use ExtUtils::MakeMaker qw/WriteMakefile prompt/;

use strict;
use warnings;

my @program;
if ( prompt( "Do you wish to install the 'runtests' utility?", "y" )
    =~ /^[Yy]/ )
{
    @program = ( EXE_FILES => ["bin/runtests"] );
}

WriteMakefile(
    'NAME'         => 'TAPx::Parser',
    'VERSION_FROM' => 'lib/TAPx/Parser.pm',
    'PREREQ_PM'    => {
        'Test::More' => '0',
        'Pod::Usage' => '0',   # for 'runtests' utility
    },
    'INSTALLDIRS' => 'site',
    'PL_FILES'    => {},
    'test'        => { 'TESTS' => 't/*.t t/compat/*.t' },
    @program,
);
