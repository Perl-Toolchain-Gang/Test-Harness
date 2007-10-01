package TAP::Harness;

use strict;
use Carp;

use File::Spec;
use File::Path;
use IO::Handle;

use TAP::Base;
use TAP::Parser;
use TAP::Parser::Aggregator;
use TAP::Parser::Multiplexer;
use TAP::Formatter::Console;

use vars qw($VERSION @ISA);

@ISA = qw(TAP::Base);

=head1 NAME

TAP::Harness - Run Perl test scripts with statistics

=head1 VERSION

Version 2.99_03

=cut

$VERSION = '2.99_03';

$ENV{HARNESS_ACTIVE}  = 1;
$ENV{HARNESS_VERSION} = $VERSION;

END {

    # For VMS.
    delete $ENV{HARNESS_ACTIVE};
    delete $ENV{HARNESS_VERSION};
}

=head1 DESCRIPTION

This is a simple test harness which allows tests to be run and results
automatically aggregated and output to STDOUT.

=head1 SYNOPSIS

 use TAP::Harness;
 my $harness = TAP::Harness->new( \%args );
 $harness->runtests(@tests);

=cut

my %VALIDATION_FOR;
my @FORMATTER_ARGS;

sub _error {
    my $self = shift;
    return $self->{error} unless @_;
    $self->{error} = shift;
}

BEGIN {

    @FORMATTER_ARGS = qw(
      directives verbose verbosity timer failures errors quiet
      really_quiet stdout color
    );

    %VALIDATION_FOR = (
        lib => sub {
            my ( $self, $libs ) = @_;
            $libs = [$libs] unless 'ARRAY' eq ref $libs;

            return [ map {"-I$_"} @$libs ];
        },
        switches  => sub { shift; shift },
        exec      => sub { shift; shift },
        merge     => sub { shift; shift },
        formatter => sub { shift; shift },
        jobs      => sub { shift; shift },
    );

    for my $method ( sort keys %VALIDATION_FOR ) {
        no strict 'refs';
        if ( $method eq 'lib' || $method eq 'switches' ) {
            *{$method} = sub {
                my $self = shift;
                unless (@_) {
                    $self->{$method} ||= [];
                    return wantarray
                      ? @{ $self->{$method} }
                      : $self->{$method};
                }
                $self->_croak("Too many arguments to method '$method'")
                  if @_ > 1;
                my $args = shift;
                $args = [$args] unless ref $args;
                $self->{$method} = $args;
                return $self;
            };
        }
        else {
            *{$method} = sub {
                my $self = shift;
                return $self->{$method} unless @_;
                $self->{$method} = shift;
            };
        }
    }

    for my $method (@FORMATTER_ARGS) {
        no strict 'refs';
        *{$method} = sub {
            my $self = shift;
            return $self->formatter->$method(@_);
        };
    }
}

##############################################################################

=head1 METHODS

=head2 Class Methods

=head3 C<auto_inherit>

Defaults to false.  Set this class constant to true in your harness
subclass to engage in "chained cooperative inheritance."  If your
subclass declares this, it is a promis to not get in the way of other
subclasses -- e.g. it should do things such call SUPER::method() from
any overridden methods.

  use base 'TAP::Harness';
  use constant auto_inherit => 1;

=cut

use constant auto_inherit => 0;

=head3 C<inherit>

When `prove` needs to utilize multiple harness subclasses, they are
built into a chain of "cooperative inheritance" (provided that their
C<auto_inherit()> method is true.)

  $class->inherit($base_class);

This typically means that $class isa TAP::Harness, though it may
ultimately work for additional schemes.

=cut

sub inherit {
    my ( $class, $base_class ) = @_;

    croak("missing required '\$base_class' argument")
      unless ( defined($base_class) );

    my $your_isa = do { no strict 'refs'; \@{"${class}::ISA"}; };

    my ( $i, @and )
      = grep { $your_isa->[$_] eq __PACKAGE__ } 0 .. $#$your_isa;
    if ( defined($i) ) {
        splice( @$your_isa, $_, 1 ) for (@and);    # cleanup (should we?)
        splice( @$your_isa, $i, 1, $base_class );
    }
    else {

        # TODO we really shouldn't get here, but the grep should do
        # something more interesting -- e.g. with isa()
        croak("cannot inherit() without isa TAP::Harness");

        # if we weren't there already, be nice like 'use base'
        push( @$your_isa, $base_class );
    }
}

=head3 C<new>

 my %args = (
    verbose => 1,
    lib     => [ 'lib', 'blib/lib' ],
 )
 my $harness = TAP::Harness->new( \%args );

The constructor returns a new C<TAP::Harness> object.  It accepts an optional
hashref whose allowed keys are:

=over 4

=item * C<verbosity>

Set the verbosity level.

=item * C<verbose>

Print individual test results to STDOUT.

=item * C<timer>

Append run time for each test to output. Uses L<Time::HiRes> if available.

=item * C<failures>

Only show test failures (this is a no-op if C<verbose> is selected).

=item * C<lib>

Accepts a scalar value or array ref of scalar values indicating which paths to
allowed libraries should be included if Perl tests are executed.  Naturally,
this only makes sense in the context of tests written in Perl.

=item * C<switches>

Accepts a scalar value or array ref of scalar values indicating which switches
should be included if Perl tests are executed.  Naturally, this only makes
sense in the context of tests written in Perl.

=item * C<color>

Attempt to produce color output.

=item * C<quiet>

Suppress some test output (mostly failures while tests are running).

=item * C<really_quiet>

Suppress everything but the tests summary.

=item * C<exec>

Typically, Perl tests are run through this.  However, anything which spits out
TAP is fine.  You can use this argument to specify the name of the program
(and optional switches) to run your tests with:

  exec => '/usr/bin/ruby -w'
  
=item * C<merge>

If C<merge> is true the harness will create parsers that merge STDOUT
and STDERR together for any processes they start.

=item * C<formatter>

If set C<formatter> must be an object that is capable of formatting
individual items from the TAP stream. For each type of item it is
capable of formatting it must expose a method called format_I<type>.

For example:

    sub format_yaml {
        my ($self, $harness, $result, $prev_result) = @_;
        # Format the item and return a string
        return _format_yaml_line( $result, $prev_result );
    }

The formatting method is called with three arguments in addition to $self:

=over

=item C<$harness>

The test harness.

=item C<$result>

The result which we should format.

=item C<$prev_result>

The previous result. This is necessary in the case of, for example,
C<format_yaml> which will want to know whether the preceding test passed
or failed.

=back

=item * C<errors>

If parse errors are found in the TAP output, a note of this will be made
in the summary report.  To see all of the parse errors, set this argument to
true:

  errors => 1

=item * C<directives>

If set to a true value, only test results with directives will be displayed.
This overrides other settings such as C<verbose> or C<failures>.

=item * C<stdout>

A filehandle for catching standard output.

=back

Any keys for which the value is C<undef> will be ignored.

=cut

# new supplied by TAP::Base

{
    my @legal_callback = qw(
      made_parser
      before_runtests
      after_runtests
    );

    sub _initialize {
        my ( $self, $arg_for ) = @_;
        $arg_for ||= {};

        $self->SUPER::_initialize( $arg_for, \@legal_callback );
        my %arg_for = %$arg_for;    # force a shallow copy

        for my $name ( sort keys %VALIDATION_FOR ) {
            my $property = delete $arg_for{$name};
            if ( defined $property ) {
                my $validate = $VALIDATION_FOR{$name};

                my $value = $self->$validate($property);
                if ( $self->_error ) {
                    $self->_croak;
                }
                $self->$name($value);
            }
        }

        $self->jobs(1) unless defined $self->jobs;

        unless ( $self->formatter ) {

            # This is a little bodge to preserve legacy behaviour. In
            # the old days we didn't get given a formatter - so in that
            # case we'll make our own formatter that provides default
            # behaviour.
            my %formatter_args = ( jobs => $self->jobs );
            for my $name (@FORMATTER_ARGS) {
                if ( defined( my $property = delete $arg_for{$name} ) ) {
                    $formatter_args{$name} = $property;
                }
            }

            $self->formatter(
                TAP::Formatter::Console->new( \%formatter_args ) );

        }

        if ( my @props = sort keys %arg_for ) {
            $self->_croak("Unknown arguments to TAP::Harness::new (@props)");
        }

        return $self;
    }
}

##############################################################################

=head2 Instance Methods

=head3 C<runtests>

  $harness->runtests(@tests);

Accepts and array of C<@tests> to be run.  This should generally be the names
of test files, but this is not required.  Each element in C<@tests> will be
passed to C<TAP::Parser::new()> as a C<source>.  See L<TAP::Parser> for more
information.

Tests will be run in the order found.

If the environment variable C<PERL_TEST_HARNESS_DUMP_TAP> is defined it
should name a directory into which a copy of the raw TAP for each test
will be written. TAP is written to files named for each test.
Subdirectories will be created as needed.

Returns a L<TAP::Parser::Aggregator> containing the test results.

=cut

sub runtests {
    my ( $self, @tests ) = @_;

    my $aggregate = TAP::Parser::Aggregator->new;

    $self->_make_callback( 'before_runtests', $aggregate );
    $self->aggregate_tests( $aggregate, @tests );
    $self->formatter->summary($aggregate);
    $self->_make_callback( 'after_runtests', $aggregate );

    return $aggregate;
}

=head3 C<aggregate_tests>

  $harness->aggregate_tests( $aggregate, @tests );

Tests will be run in the order found.

=cut

sub aggregate_tests {
    my ( $self, $aggregate, @tests ) = @_;

    my $jobs = $self->jobs;

    $self->formatter->prepare(@tests);
    $aggregate->start;

    if ( $jobs > 1 ) {
        my $mux = TAP::Parser::Multiplexer->new;

        RESULT: {

            # Keep multiplexer topped up
            while ( @tests && $mux->parsers < $jobs ) {
                my $test    = shift @tests;
                my $parser  = $self->make_parser($test);
                my $session = $self->formatter->open_test( $test, $parser );
                $mux->add( $parser, [ $session, $test ] );
            }

            if ( my ( $parser, $stash, $result ) = $mux->next ) {
                my ( $session, $test ) = @$stash;
                if ( defined $result ) {
                    $session->result($result);
                    exit 1 if $result->is_bailout;
                }
                else {

                    # End of parser. Automatically removed from the mux.
                    $self->finish_parser( $parser, $session );
                    $aggregate->add( $test, $parser );
                }
                redo RESULT;
            }
        }
    }
    else {
        for my $test (@tests) {
            my $parser = $self->make_parser($test);
            my $session = $self->formatter->open_test( $test, $parser );

            while ( defined( my $result = $parser->next ) ) {
                $session->result($result);
                exit 1 if $result->is_bailout;
            }

            $self->finish_parser( $parser, $session );

            # my $parser = $self->_runtest($test);
            $aggregate->add( $test, $parser );
        }
    }
    $aggregate->stop;

}

=head3 C<jobs>

Returns the number of concurrent test runs the harness is handling. For the default
harness this value is always 1. A parallel harness such as L<TAP::Harness::Parallel>
will override this to return the number of jobs it is handling.

=cut

##############################################################################

=head1 SUBCLASSING

C<TAP::Harness> is designed to be (mostly) easy to subclass.  If you don't
like how a particular feature functions, just override the desired methods.

=head2 Methods

TODO: This is out of date

The following methods are ones you may wish to override if you want to
subclass C<TAP::Harness>.

=head3 C<summary>

  $harness->summary( \%args );

C<summary> prints the summary report after all tests are run.  The argument is
a hashref with the following keys:

=over 4

=item * C<start>

This is created with C<< Benchmark->new >> and it the time the tests started.
You can print a useful summary time, if desired, with:

  $self->output(timestr( timediff( Benchmark->new, $start_time ), 'nop' ));

=item * C<tests>

This is an array reference of all test names.  To get the L<TAP::Parser>
object for individual tests:

 my $aggregate = $args->{aggregate};
 my $tests     = $args->{tests};

 for my $name ( @$tests ) {
     my ($parser) = $aggregate->parsers($test);
     ... do something with $parser
 }

This is a bit clunky and will be cleaned up in a later release.

=back

=cut

sub _get_parser_args {
    my ( $self, $test ) = @_;
    my %args = ();
    my @switches = $self->lib if $self->lib;
    push @switches => $self->switches if $self->switches;
    $args{switches} = \@switches;
    $args{spool}    = $self->_open_spool($test);
    $args{merge}    = $self->merge;
    $args{exec}     = $self->exec;
    if ( my $exec = $self->exec ) {
        $args{exec} = [ @$exec, $test ];
    }
    else {
        $args{source} = $test;
    }
    return \%args;
}

=head3 C<make_parser>

Make a new parser. Typically used and/or overridden in subclasses.

=cut

sub make_parser {
    my ( $self, $test ) = @_;

    my $parser = TAP::Parser->new( $self->_get_parser_args($test) );

    $self->_make_callback( 'made_parser', $parser );

    return $parser;
}

=head3 C<finish_parser>

Terminate use of a parser. Typically used and/or overridden in
subclasses. The parser isn't destroyed as a result of this.

=cut

sub finish_parser {
    my ( $self, $parser, $session ) = @_;

    $session->close_test;
    $self->_close_spool($parser);

    return $parser;
}

sub _open_spool {
    my $self = shift;
    my $test = shift;

    if ( my $spool_dir = $ENV{PERL_TEST_HARNESS_DUMP_TAP} ) {

        my $spool = File::Spec->catfile( $spool_dir, $test );

        # Make the directory
        my ( $vol, $dir, undef ) = File::Spec->splitpath($spool);
        my $path = File::Spec->catpath( $vol, $dir, '' );
        eval { mkpath($path) };
        $self->_croak($@) if $@;

        my $spool_handle = IO::Handle->new;
        open( $spool_handle, ">$spool" )
          or $self->_croak(" Can't write $spool ( $! ) ");

        return $spool_handle;
    }

    return;
}

sub _close_spool {
    my $self = shift;
    my ($parser) = @_;

    if ( my $spool_handle = $parser->delete_spool ) {
        close($spool_handle)
          or $self->_croak(" Error closing TAP spool file( $! ) \n ");
    }

    return;
}

sub _croak {
    my ( $self, $message ) = @_;
    unless ($message) {
        $message = $self->_error;
    }
    $self->SUPER::_croak($message);

    return;
}

=head1 REPLACING

If you like the C<prove> utility and L<TAP::Parser> but you want your
own harness, all you need to do is write one and provide C<new> and
C<runtests> methods. Then you can use the C<prove> utility like so:

 prove --harness My::Test::Harness

Note that while C<prove> accepts a list of tests (or things to be
tested), C<new> has a fairly rich set of arguments. You'll probably want
to read over this code carefully to see how all of them are being used.

=head1 SEE ALSO

L<Test::Harness>

=cut

1;

# vim:ts=4:sw=4:et:sta
