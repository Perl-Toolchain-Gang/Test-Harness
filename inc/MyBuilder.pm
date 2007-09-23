package MyBuilder;

BEGIN {
    require Module::Build;
    @ISA = qw(Module::Build);
}

sub ACTION_testprove {
    my $self = shift;
    $self->depends_on('code');
    exec($^X, '-Iblib/lib', 'bin/prove', '-r');
}


sub ACTION_testreference {
    my $self = shift;
    $self->depends_on('code');
    my $ref = 'reference/Test-Harness-2.64';
    exec($^X,
         (-e $ref ? ("-I$ref/lib", "$ref/bin/prove") : qw(-S prove) ),
         '-Iblib/lib', '-r', 't'
    );
}


sub ACTION_testauthor {
      my $self = shift;
      $self->test_files('t', 'xt/author');
      $self->generic_test( type => 'default' );
}

1;
