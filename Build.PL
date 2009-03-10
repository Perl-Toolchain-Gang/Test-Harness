#!perl

require 5.006;

use strict;
use Module::Build;

use File::Spec;
use lib 'inc', File::Spec->canonpath('lib/');    # use our self to install

use MyBuilder;

my $builder = MyBuilder->new(
    module_name => 'Test::Harness',
    license     => 'perl',
    installdirs => 'core',
    meta_merge  => {
        resources => {
            homepage => 'http://testanything.org/',
            bugtracker =>
              'http://rt.cpan.org/Public/Dist/Display.html?Name=Test-Harness',
            MailingList => 'mailto:<tapx-dev@hexten.net>',
            repository =>
              'http://svn.hexten.net/tapx/trunk',
        },
        keywords => [ 'TAP', 'test harness', 'prove' ],
    },
    recursive_test_files => 1,
    requires             => {
        'File::Spec' => '0.8',    # for 'rel2abs'
    },
    recommends => {
        'Pod::Usage' => '1.12',    # for 'prove'
    },
    build_requires => {},
    add_to_cleanup => ['Test-Harness-*'],
    script_files   => ["bin/prove"],
);

$builder->create_build_script();
