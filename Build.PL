use strict;
use warnings;
use Module::Build;
use 5.005;

my $builder = Module::Build->new(
    module_name       => 'TAPx::Parser',
    license           => 'perl',
    dist_author       => 'Curtis "Ovid" Poe <ovid@cpan.org>',
    dist_version_from => 'lib/TAPx/Parser.pm',
    requires          => {
        'Test::More' => 0,
        'Pod::Usage' => 0,    # for 'runtests'
    },
    add_to_cleanup => ['TAPx-Parser-*'],
);

if ( $builder->prompt( "Do you wish to install the 'runtests' utility?", "y" )
    =~ /^[Yy]/ )
{
    $builder->script_files( ["bin/runtests"] );
}

$builder->create_build_script();
