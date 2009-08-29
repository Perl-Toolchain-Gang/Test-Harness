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

use Test::More tests => 42;

use IO::File;
use File::Spec;
use TAP::Parser::Source;
use TAP::Parser::SourceFactory;

# Test generic API...
{
    can_ok 'TAP::Parser::SourceFactory', 'new';
    my $sf = TAP::Parser::SourceFactory->new;
    isa_ok $sf, 'TAP::Parser::SourceFactory';
    can_ok $sf, 'config';
    can_ok $sf, 'detectors';
    can_ok $sf, 'detect_source';
    can_ok $sf, 'make_iterator';
    can_ok $sf, 'register_detector';

    # Set config
    eval { $sf->config('bad config') };
    my $e = $@;
    like $e, qr/\QArgument to &config must be a hash reference/,
      '... and calling config with bad config should fail';

    my $config = { MySourceDetector => { foo => 'bar' } };
    is( $sf->config($config), $sf, '... and set config works' );

    # Load/Register a detector
    $sf = TAP::Parser::SourceFactory->new(
        { MySourceDetector => { accept => 'known-source' } } );
    can_ok( 'MySourceDetector', 'can_handle' );
    is_deeply( $sf->detectors, ['MySourceDetector'], '... was registered' );

    # Known source should pass
    {
	my $source = TAP::Parser::Source->new->raw( \'known-source' );
        my $iterator = eval { $sf->make_iterator( $source ) };
        my $error = $@;
        ok( !$error, 'make_iterator with known source doesnt fail' );
        diag($error) if $error;
        isa_ok( $iterator, 'MyIterator', '... and iterator class' );
    }

    # No known source should fail
    {
	my $source = TAP::Parser::Source->new->raw( \'unknown-source' );
        my $iterator = eval { $sf->make_iterator( $source ) };
        my $error = $@;
        ok( $error, 'make_iterator with unknown source fails' );
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
        detector => 'TAP::Parser::SourceDetector::File',
        iterator => 'TAP::Parser::Iterator::Stream',
    },
    {   file   => 'source.1',
        detector  => 'TAP::Parser::SourceDetector::File',
        config => { File => { extensions => ['.1'] } },
        iterator => 'TAP::Parser::Iterator::Stream',
    },
    {   file  => 'source.pl',
        detector => 'TAP::Parser::SourceDetector::Perl',
        iterator => 'TAP::Parser::Iterator::Process',
    },
    {   file  => 'source.t',
        detector => 'TAP::Parser::SourceDetector::Perl',
        iterator => 'TAP::Parser::Iterator::Process',
    },
    {   file  => 'source',
        detector => 'TAP::Parser::SourceDetector::Perl',
        iterator => 'TAP::Parser::Iterator::Process',
    },
    {   file  => 'source.sh',
        detector => 'TAP::Parser::SourceDetector::Executable',
        iterator => 'TAP::Parser::Iterator::Process',
    },
    {   file  => 'source.bat',
        detector => 'TAP::Parser::SourceDetector::Executable',
        iterator => 'TAP::Parser::Iterator::Process',
    },
    {   name   => 'raw tap string',
        source => "0..1\nok 1 - raw tap\n",
        detector  => 'TAP::Parser::SourceDetector::RawTAP',
        iterator => 'TAP::Parser::Iterator::Array',
    },
    {   name   => 'raw tap array',
        source => [ "0..1\n", "ok 1 - raw tap\n" ],
        detector  => 'TAP::Parser::SourceDetector::RawTAP',
        iterator => 'TAP::Parser::Iterator::Array',
    },
    {   source => \*__DATA__,
        detector  => 'TAP::Parser::SourceDetector::Handle',
        iterator => 'TAP::Parser::Iterator::Stream',
    },
    {   source => IO::File->new('-'),
        detector  => 'TAP::Parser::SourceDetector::Handle',
        iterator => 'TAP::Parser::Iterator::Stream',
    },
);

foreach my $test (@sources) {
    local $TODO = $test->{TODO};
    if ( $test->{file} ) {
        $test->{name} = $test->{file};
        $test->{source} = File::Spec->catfile( $test_dir, $test->{file} );
    }

    my $name = $test->{name} || substr( $test->{source}, 0, 10 );
    my $sf = TAP::Parser::SourceFactory->new( $test->{config} )->_testing( 1 );

    my $raw     = $test->{source};
    my $source  = TAP::Parser::Source->new->raw( ref($raw) ? $raw : \$raw );
    my $iterator = eval { $sf->make_iterator( $source ) };
    my $error   = $@;
    ok( !$error, "$name: no error on make_iterator" );
    diag($error) if $error;
#    isa_ok( $iterator, $test->{iterator}, $name );
    is( $sf->_last_detector, $test->{detector}, $name );
}

__END__
0..1
ok 1 - TAP in the __DATA__ handle
