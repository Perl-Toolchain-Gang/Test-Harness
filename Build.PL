use strict;
use Module::Build;
use 5.005;

# NOTE: make this actually be inc/MyBuilder.pm if it gets any bigger
my $build_class = Module::Build->subclass(
    class => 'inc::MyBuilder',
    code  => <<'    SUBCLASS',
      sub ACTION_testprove {
          my $self = shift;
          $self->depends_on('code');
          exec($^X, '-Iblib/lib', 'bin/prove', '-r');
      }
    SUBCLASS
);

my $builder = $build_class->new(
    module_name => 'Test::Harness',
    license     => 'perl',
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
    },
    recommends           => {
        'Pod::Usage' => '1.12',    # for 'prove'
    },
    build_requires       => {
    },
    add_to_cleanup => ['Test-Harness-*'],
    script_files => ["bin/prove"],
);

$builder->create_build_script();
