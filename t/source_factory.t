#!/usr/bin/perl -w

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

use Test::More tests => 35;

use IO::File;
use File::Spec;
use TAP::Parser::SourceFactory;

can_ok 'TAP::Parser::SourceFactory', 'new';
my $sf = TAP::Parser::SourceFactory->new;
isa_ok $sf, 'TAP::Parser::SourceFactory';
can_ok $sf, 'detect_source';
can_ok $sf, 'make_source';
can_ok $sf, 'register_detector';

# Register a detector
use_ok('MySourceDetector');
is_deeply( $sf->detectors, ['MySourceDetector'], '... was registered' );

# Known source should pass
{
    my $source;
    eval { $source = $sf->make_source( \"known-source" ) };
    my $error = $@;
    ok( !$error, 'make_source with known source doesnt fail' );
    diag($error) if $error;
}

# No known source should fail
{
    my $source;
    eval { $source = $sf->make_source( \"unknown-source" ) };
    my $error = $@;
    ok( $error, 'make_source with unknown source fails' );
    like $error, qr/^Couldn't detect source of 'unknown-source'/,
      '... with an appropriate error message';
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

my @sources =
  (
   {
    file  => 'source.tap',
    class => 'TAP::Parser::Source::File',
   },
   {
    file  => 'source.pl',
    class => 'TAP::Parser::Source::Perl',
   },
   {
    file  => 'source.t',
    class => 'TAP::Parser::Source::Perl',
   },
   {
    file  => 'source',
    class => 'TAP::Parser::Source::Perl',
   },
   {
    file  => 'source.sh',
    class => 'TAP::Parser::Source::Executable',
   },
   {
    file  => 'source.bat',
    class => 'TAP::Parser::Source::Executable',
   },
   {
    name   => 'raw tap string',
    source => "0..1\nok 1 - raw tap\n",
    class  => 'TAP::Parser::Source::RawTAP',
   },
   {
    name   => 'raw tap array',
    source => ["0..1\n", "ok 1 - raw tap\n"],
    class  => 'TAP::Parser::Source::RawTAP',
   },
   {
    source => \*__DATA__,
    class  => 'TAP::Parser::Source::Handle',
   },
   {
    source => IO::File->new('-'),
    class  => 'TAP::Parser::Source::Handle',
   },
  );

foreach my $test (@sources) {
    local $TODO = $test->{TODO};
    if ($test->{file}) {
	$test->{name}   = $test->{file};
	$test->{source} = File::Spec->catfile( $test_dir, $test->{file} );
    }

    my $name = $test->{name} || substr( $test->{source}, 0, 10 );
    my $raw_source = $test->{source};
    my $source;
    eval { $source = $sf->make_source( ref( $raw_source ) ? $raw_source : \$raw_source ) };
    my $error = $@;
    ok( !$error, "$name: no error on make_source" );
    diag( $error ) if $error;
    isa_ok( $source, $test->{class}, $name );
}


__END__
0..1
ok 1 - TAP in the __DATA__ handle
