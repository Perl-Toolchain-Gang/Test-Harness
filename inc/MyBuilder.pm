package MyBuilder;

BEGIN {
    require Module::Build;
    @ISA = qw(Module::Build);
}

# Test with Test::Harness
sub ACTION_test_with_harness {
    my $self = shift;

    $self->SUPER::ACTION_test(@_);
}

# Test with TAP::Harness instead of Test::Harness
sub ACTION_test {
    my $self = shift;

    $self->depends_on('code');

    my $tests = $self->find_test_files;
    unless (@$tests) {
        $self->log_info("No tests defined.\n");
        return;
    }

    # TODO verbose and stuff

    require TAP::Harness;
    my $harness = TAP::Harness->new( { lib => 'blib/lib' } );
    my $aggregator = $harness->runtests(@$tests);
    exit $aggregator->has_problems ? 1 : 0;
}

sub ACTION_testprove {
    my $self = shift;
    $self->depends_on('code');
    exec( $^X, '-Iblib/lib', 'bin/prove', '-b', '-r' );
}

sub ACTION_testreference {
    my $self = shift;
    $self->depends_on('code');
    my $ref = 'reference/Test-Harness-2.64';
    exec( $^X,
        ( -e $ref ? ( "-I$ref/lib", "$ref/bin/prove" ) : qw(-S prove) ),
        '-Iblib/lib', '-r', 't'
    );
}

sub ACTION_testauthor {
    my $self = shift;
    $self->test_files( 'xt/author' );
    $self->ACTION_test;
}

sub ACTION_critic {
    exec(
        qw(perlcritic -1 -q -profile perlcriticrc
          bin/prove lib/), glob('t/*.t')
    );
}

sub ACTION_tags {
    exec(
        qw(ctags -f tags --recurse --totals
          --exclude=blib
          --exclude=.svn
          --exclude='*~'
          --languages=Perl
          t/ lib/ bin/prove
          )
    );
}

sub ACTION_tidy {
    my $self = shift;

    my $pms = $self->find_pm_files;
    for my $file ( keys %$pms ) {
        system( 'perltidy', '-b', $file );
        unlink("$file.bak") if $? == 0;
    }
}

1;
