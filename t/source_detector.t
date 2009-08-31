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

use Test::More tests => 58;

use IO::File;
use IO::Handle;
use File::Spec;

use TAP::Parser::Source;
use TAP::Parser::SourceDetector;
use TAP::Parser::SourceDetector::Perl;
use TAP::Parser::SourceDetector::File;
use TAP::Parser::SourceDetector::RawTAP;
use TAP::Parser::SourceDetector::Handle;

my $dir = File::Spec->catdir(
    (   $ENV{PERL_CORE}
        ? ( File::Spec->updir(), 'ext', 'Test-Harness' )
        : ()
    ),
    't',
    'source_tests'
);

my $perl = $^X;

# Abstract base class tests
{
    my $class  = 'TAP::Parser::SourceDetector';
    my $source = TAP::Parser::Source->new;
    my $error;

    can_ok $class, 'can_handle';
    eval { $class->can_handle( $source ) };
    $error = $@;
    like $error, qr/^Abstract method 'can_handle'/,
      '... with an appropriate error message';

    can_ok $class, 'make_iterator';
    eval { $class->make_iterator( $source ) };
    $error = $@;
    like $error, qr/^Abstract method 'make_iterator'/,
      '... with an appropriate error message';
}

# Executable source tests
{
    my $class = 'TAP::Parser::SourceDetector::Executable';
    my $test  = File::Spec->catfile( $dir, 'source' );
    my $tests =
      {
       default_vote => 0,
       can_handle =>
       [
	{
	 name => '.sh',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '.sh' }
		 },
	 vote => 0.8,
	},
	{
	 name => '.bat',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '.bat' }
		 },
	 vote => 0.8,
	},
	{
	 name => 'executable bit',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '', execute => 1 }
		 },
	 vote => 0.7,
	},
	{
	 name => 'exec hash',
	 raw  => { exec => 'foo' },
	 meta => { is_hash => 1 },
	 vote => 0.9,
	},
       ],
       make_iterator =>
       [
	{
	 name   => "valid executable",
	 raw    => [ $perl, '-It/lib', '-T', $test ],
	 iclass => 'TAP::Parser::Iterator::Process',
	 output => [ '1..1', 'ok 1' ],
	},
	{
	 name  => "invalid source->raw",
	 raw   => "$perl -It/lib $test",
	 error => qr/^Argument to &raw_source must be an array reference/,
	},
	{
	 name  => "non-existent source->raw",
	 raw   => [],
	 error => qr/No command found!/,
	},
       ],
      };

    test_detector( $class, $tests );
}

# Perl source tests
{
    my $class = 'TAP::Parser::SourceDetector::Perl';
    my $test  = File::Spec->catfile( $dir, 'source' );
    my $tests =
      {
       default_vote => 0,
       can_handle =>
       [
	{
	 name => '.t',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '.t', dir => '' }
		 },
	 vote => 0.8,
	},
	{
	 name => '.pl',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '.pl', dir => '' }
		 },
	 vote => 0.9,
	},
	{
	 name => 't/.../file',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '', dir => 't' }
		 },
	 vote => 0.75,
	},
	{
	 name => '#!...perl',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '', dir => '', shebang => '#!/usr/bin/perl' }
		 },
	 vote => 0.9,
	},
	{
	 name => 'file default',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '', dir => '' }
		 },
	 vote => 0.25,
	},
       ],
       make_iterator =>
       [
	{
	 name   => $test,
	 raw    => \$test,
	 iclass => 'TAP::Parser::Iterator::Process',
	 output => [ '1..1', 'ok 1' ],
	 assemble_meta => 1,
	},
       ],
      };

    test_detector( $class, $tests );

    # internals tests!
    {
	my $source = TAP::Parser::Source->new->raw( \$test );
	$source->assemble_meta;
	my $iterator = $class->make_iterator( $source );
	my @command  = @{ $iterator->{command} };
	ok( grep( $_ =~ /^['"]?-T['"]?$/, @command ),
	    '... and it should find the taint switch' );
    }
}

# Raw TAP source tests
{
    my $class = 'TAP::Parser::SourceDetector::RawTAP';
    my $tests =
      {
       default_vote => 0,
       can_handle =>
       [
	{
	 name => 'file',
	 meta => { is_file => 1 },
	 raw  => \'',
	 vote => 0,
	},
	{
	 name => 'scalar w/newlines',
	 meta => { is_scalar => 1, has_newlines => 1 },
	 raw  => \'',
	 vote => 0.6,
	},
	{
	 name => '1..10',
	 meta => { is_scalar => 1, has_newlines => 1 },
	 raw  => \"1..10\n",
	 vote => 0.9,
	},
	{
	 name => 'array',
	 meta => { is_array => 1 },
	 raw  => ['1..1', 'ok 1'],
	 vote => 0.5,
	},
       ],
       make_iterator =>
       [
	{
	 name   => 'valid scalar',
	 raw    => \"1..1\nok 1 - raw\n",
	 iclass => 'TAP::Parser::Iterator::Array',
	 output => [ '1..1', 'ok 1 - raw' ],
	},
	{
	 name   => 'valid array',
	 raw    => [ '1..1', 'ok 1 - raw' ],
	 iclass => 'TAP::Parser::Iterator::Array',
	 output => [ '1..1', 'ok 1 - raw' ],
	},
       ],
      };

    test_detector( $class, $tests );
}

# Text file TAP source tests
{
    my $test  = File::Spec->catfile( $dir, 'source.tap' );
    my $class = 'TAP::Parser::SourceDetector::File';
    my $tests =
      {
       default_vote => 0,
       can_handle =>
       [
	{
	 name => '.tap',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '.tap' }
		 },
	 vote => 0.9,
	},
	{
	 name => '.foo with config',
	 meta => {
		  is_file => 1,
		  file => { lc_ext => '.foo' }
		 },
	 config => { File => { extensions => ['.foo'] } },
	 vote => 0.9,
	},
       ],
       make_iterator =>
       [
	{
	 name   => $test,
	 raw    => \$test,
	 iclass => 'TAP::Parser::Iterator::Stream',
	 output => [ '1..1', 'ok 1' ],
	 assemble_meta => 1,
	},
       ],
      };

    test_detector( $class, $tests );
}

# IO::Handle TAP source tests
{
    my $test  = File::Spec->catfile( $dir, 'source.tap' );
    my $class = 'TAP::Parser::SourceDetector::Handle';
    my $tests =
      {
       default_vote => 0,
       can_handle =>
       [
	{
	 name => 'glob',
	 meta => { is_glob => 1 },
	 vote => 0.8,
	},
	{
	 name => 'IO::Handle',
	 raw  => IO::Handle->new,
	 vote => 0.9,
	 assemble_meta => 1,
	},
       ],
       make_iterator =>
       [
	{
	 name   => 'IO::Handle',
	 raw    => IO::File->new( $test ),
	 iclass => 'TAP::Parser::Iterator::Stream',
	 output => [ '1..1', 'ok 1' ],
	 assemble_meta => 1,
	},
       ],
      };

    test_detector( $class, $tests );
}

exit;

###############################################################################
# helper sub

sub test_detector {
    my ($class, $tests) = @_;
    my ($short_class) = ($class =~ /\:\:(\w+)$/);

    can_ok $class, 'can_handle', 'make_iterator';

    {
	my $default_vote = $tests->{default_vote} || 0;
	my $source = TAP::Parser::Source->new;
	is( $class->can_handle( $source ), $default_vote, '... can_handle default vote' );
    }

    foreach my $test (@{ $tests->{can_handle} }) {
	my $source = TAP::Parser::Source->new;
	$source->raw( $test->{raw} ) if $test->{raw};
	$source->meta( $test->{meta} ) if $test->{meta};
	$source->config( $test->{config} ) if $test->{config};
	$source->assemble_meta if $test->{assemble_meta};
	my $vote = $test->{vote} || 0;
	my $name = $test->{name} || 'unnamed test';
	$name    = "$short_class->can_handle( $name )";
	is( $class->can_handle( $source ), $vote, $name );
    }

    foreach my $test (@{ $tests->{make_iterator} }) {
	my $name = $test->{name} || 'unnamed test';
	$name    = "$short_class->make_iterator( $name )";

	my $source = TAP::Parser::Source->new;
	$source->raw( $test->{raw} ) if $test->{raw};
	$source->meta( $test->{meta} ) if $test->{meta};
	$source->config( $test->{config} ) if $test->{config};
	$source->assemble_meta if $test->{assemble_meta};

	my $iterator = eval { $class->make_iterator( $source ) };
	my $e = $@;
	if (my $error = $test->{error}) {
	    $e = '' unless defined $e;
	    like $e, $error, "$name threw expected error";
	    next;
	} elsif ($e) {
	    fail( "$name threw an unexpected error" );
	    diag( $e );
	    next;
	}

	isa_ok $iterator, $test->{iclass}, $name;
	if ($test->{output}) {
	    my $i = 1;
	    foreach my $line (@{ $test->{output} }) {
		is $iterator->next, $line, "... line $i";
		$i++;
	    }
	    ok !$iterator->next, '... and we should have no more results';
	}
    }
}
