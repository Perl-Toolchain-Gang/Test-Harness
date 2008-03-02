#!/cygdrive/c/Perl/bin/perl

use strict;
use warnings;

$ENV{PATH} = join ';',
  'C:\Program Files\Microsoft Visual Studio 8\Common7\IDE',
  'C:\Program Files\Microsoft Visual Studio 8\VC\BIN',
  'C:\Program Files\Microsoft Visual Studio 8\Common7\Tools',
  'C:\Program Files\Microsoft Visual Studio 8\SDK\v2.0\bin',
  'C:\WINDOWS\Microsoft.NET\Framework\v2.0.50727',
  'C:\Program Files\Microsoft Visual Studio 8\VC\VCPackages',
  'C:\Perl\bin', 'C:\WINDOWS\system32',
  'C:\WINDOWS',  'C:\WINDOWS\System32\Wbem';

my $perl = $^X;

my $rc = shell_run( [ $perl, 'Makefile.PL' ],
    'nmake', 'nmake test', 'nmake distclean' )
  or shell_run(
    [ $perl, 'Build.PL' ],
    'Build',
    'Build test',
    'Build testprove',
    'Build distclean'
  );

exit $rc;

sub shell_run {
    for my $cmd ( @_ ) {
        my $rc = system( 'ARRAY' eq ref $cmd ? @$cmd : $cmd );
        return $rc if $rc;
    }
    return 0;
}
