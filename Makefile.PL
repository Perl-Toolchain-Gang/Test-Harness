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

{

    package MY;

    use File::Spec;
    use Config;

    sub test_via_harness {
        my ( $self, $orig_perl, $tests ) = @_;

        my $perl5lib = join $Config{path_sep},
          grep { defined && length } File::Spec->canonpath('lib/'),
          $ENV{PERL5LIB};

        my $perl = "PERL5LIB=$perl5lib $orig_perl";
        return $self->SUPER::test_via_harness( $perl, $tests );
    }
}
