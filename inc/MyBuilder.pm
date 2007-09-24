package MyBuilder;

BEGIN {
    require Module::Build;
    @ISA = qw(Module::Build);
}

sub ACTION_testprove {
    my $self = shift;
    $self->depends_on('code');
    exec( $^X, '-Iblib/lib', 'bin/prove', '-r' );
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
    $self->test_files( 't', 'xt/author' );
    $self->generic_test( type => 'default' );
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
