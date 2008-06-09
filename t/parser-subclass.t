#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use vars qw(%INIT %CUSTOM);

use Test::More tests => 16;
use File::Spec::Functions qw( catfile );

use_ok( 'TAP::Parser::SubclassTest' );

# TODO: foreach my $source ( ... )
my $t_dir = $ENV{PERL_CORE} ? 'lib' : 't';

{ # perl source
    %INIT = %CUSTOM = ();
    my $source = catfile( $t_dir, 'subclass_tests', 'perl_source' );
    my $p = TAP::Parser::SubclassTest->new( { source => $source } );
    
    # The grammar is lazily constructed so we need to ask for it to
    # trigger it's creation.
    my $grammer = $p->_grammar;
    
    ok( $p->{initialized}, 'new subclassed parser' );

    is( $p->source_class      => 'MySource', 'source_class' );
    is( $p->perl_source_class => 'MyPerlSource', 'perl_source_class' );
    is( $p->grammar_class     => 'MyGrammar', 'grammar_class' );
    is( $p->iterator_factory_class => 'MyIteratorFactory', 'iterator_factory_class' );
    is( $p->result_factory_class   => 'MyResultFactory', 'result_factory_class' );

    is( $INIT{MyPerlSource}, 1, 'initialized MyPerlSource' );
    is( $INIT{MyGrammar}, 1, 'initialized MyGrammar' );

    # make sure overrided make_* methods work...
    %CUSTOM = ();
    $p->make_source;
    is( $CUSTOM{MySource}, 1, 'make custom source' );
    $p->make_perl_source;
    is( $CUSTOM{MyPerlSource}, 1, 'make custom perl source' );
    $p->make_grammar;
    is( $CUSTOM{MyGrammar}, 1, 'make custom grammar' );
    $p->make_iterator;
    is( $CUSTOM{MyIterator}, 1, 'make custom iterator' );
    $p->make_result;
    is( $CUSTOM{MyResult}, 1, 'make custom result' );
}

TODO: { # non-perl source
    local $TODO = 'not yet tested';
    %INIT = %CUSTOM = ();
    my $source = catfile( $t_dir, 'subclass_tests', 'non_perl_source' );
    my $p = TAP::Parser::SubclassTest->new( { source => $source } );

    is( $INIT{MySource}, 1, 'initialized MySource subclass' );
    is( $INIT{MyIterator}, 1, 'initialized MyIterator subclass' );
}


#use Data::Dumper;
#print Dumper( \%INIT );
#print Dumper( \%CUSTOM );
