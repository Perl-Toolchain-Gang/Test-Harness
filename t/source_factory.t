#!/usr/bin/perl -w
#
# Tests for TAP::Parser::SourceFactory & source detection
##

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', '../ext/Test-Harness/t/lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::More tests => 44;

use IO::File;
use File::Spec;
use TAP::Parser::SourceFactory;

# Test generic API...
{
    can_ok 'TAP::Parser::SourceFactory', 'new';
    my $sf = TAP::Parser::SourceFactory->new;
    isa_ok $sf, 'TAP::Parser::SourceFactory';
    can_ok $sf, 'config';
    can_ok $sf, 'sources';
    can_ok $sf, 'detect_source';
    can_ok $sf, 'make_source';
    can_ok $sf, 'register_source';

    # Set config
    eval { $sf->config('bad config') };
    my $e = $@;
    like $e, qr/\QArgument to &config must be a hash reference/,
      '... and calling config with bad config should fail';

    my $config = { MySourceDetector => { foo => 'bar' } };
    is( $sf->config($config), $sf, '... and set config works' );

    # Load/Register a source
    $sf = TAP::Parser::SourceFactory->new(
        { MySourceDetector => { accept => 'known-source' } } );
    can_ok( 'MySourceDetector', 'can_handle' );
    is_deeply( $sf->sources, ['MySourceDetector'], '... was registered' );

    # Known source should pass
    {
        my $source;
        eval {
            $source
              = $sf->make_source( { raw_source_ref => \"known-source" } );
        };
        my $error = $@;
        ok( !$error, 'make_source with known source doesnt fail' );
        diag($error) if $error;
        isa_ok( $source, 'MySourceDetector', '... and source class' );
        is_deeply(
            $source->raw_source, [ \"known-source" ],
            '... and raw_source as expected'
        );
        is_deeply(
            $source->config, { accept => 'known-source' },
            '... and source config as expected'
        );
    }

    # No known source should fail
    {
        my $source;
        eval {
            $source
              = $sf->make_source( { raw_source_ref => \"unknown-source" } );
        };
        my $error = $@;
        ok( $error, 'make_source with unknown source fails' );
        like $error, qr/^Cannot detect source of 'unknown-source'/,
          '... with an appropriate error message';
    }
}

# Source detection
use_ok('TAP::Parser::SourceDetector::Executable');
use_ok('TAP::Parser::SourceDetector::Perl');
use_ok('TAP::Parser::SourceDetector::File');
use_ok('TAP::Parser::SourceDetector::RawTAP');
use_ok('TAP::Parser::SourceDetector::Handle');

my $test_dir = File::Spec->catdir(
    (   $ENV{PERL_CORE}
        ? ( File::Spec->updir(), 'ext', 'Test-Harness' )
        : ()
    ),
    't',
    'source_tests'
);

my @sources = (
    {   file  => 'source.tap',
        class => 'TAP::Parser::SourceDetector::File',
    },
    {   file   => 'source.1',
        class  => 'TAP::Parser::SourceDetector::File',
        config => { File => { extensions => ['.1'] } },
    },
    {   file  => 'source.pl',
        class => 'TAP::Parser::SourceDetector::Perl',
    },
    {   file  => 'source.t',
        class => 'TAP::Parser::SourceDetector::Perl',
    },
    {   file  => 'source',
        class => 'TAP::Parser::SourceDetector::Perl',
    },
    {   file  => 'source.sh',
        class => 'TAP::Parser::SourceDetector::Executable',
    },
    {   file  => 'source.bat',
        class => 'TAP::Parser::SourceDetector::Executable',
    },
    {   name   => 'raw tap string',
        source => "0..1\nok 1 - raw tap\n",
        class  => 'TAP::Parser::SourceDetector::RawTAP',
    },
    {   name   => 'raw tap array',
        source => [ "0..1\n", "ok 1 - raw tap\n" ],
        class  => 'TAP::Parser::SourceDetector::RawTAP',
    },
    {   source => \*__DATA__,
        class  => 'TAP::Parser::SourceDetector::Handle',
    },
    {   source => IO::File->new('-'),
        class  => 'TAP::Parser::SourceDetector::Handle',
    },
);

foreach my $test (@sources) {
    local $TODO = $test->{TODO};
    if ( $test->{file} ) {
        $test->{name} = $test->{file};
        $test->{source} = File::Spec->catfile( $test_dir, $test->{file} );
    }

    my $name = $test->{name} || substr( $test->{source}, 0, 10 );
    my $sf = TAP::Parser::SourceFactory->new( $test->{config} );

    my $raw_source = $test->{source};
    my $source;
    eval {
        my $ref = ref($raw_source) ? $raw_source : \$raw_source;
        $source = $sf->make_source( { raw_source_ref => $ref } );
    };
    my $error = $@;
    ok( !$error, "$name: no error on make_source" );
    diag($error) if $error;
    isa_ok( $source, $test->{class}, $name );
}

__END__
0..1
ok 1 - TAP in the __DATA__ handle
