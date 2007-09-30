package MyBuilder;

BEGIN {
    require Module::Build;
    @ISA = qw(Module::Build);
}

# should *maybe* work iff we get the compatibility layer right
sub ACTION_testcrufty {
    my $self = shift;

    $self->SUPER::ACTION_test(@_);
}

# Let's just forget about trying to use the compatibility layer to
# self-test.
sub ACTION_test {
    my $self = shift;

    my $tests = $self->find_test_files;
    unless (@$tests) {
        $self->log_info("No tests defined.\n");
        return;
    }

    # We want to break the longstanding tradition of pushing the LHS
    # @INC into the RHS processes.  At least, only push the ones which
    # aren't in the LHS's perl's @INC because the RHS perl might be a
    # different version.

    # TODO verbose and stuff

    require TAP::Harness;
    my $harness = TAP::Harness->new( { lib => 'blib/lib' } );
    my $aggregator = $harness->runtests(@$tests);
    exit $aggregator->has_problems ? 1 : 0;
}

sub ACTION_testprove {
    my $self = shift;
    $self->depends_on('code');
    exec( $^X, '-Iblib/lib', 'bin/prove', '-I', 'blib/lib', '-r' );
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
