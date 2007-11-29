package App::Prove::State;

use strict;
use File::Find;
use File::Spec;
use Carp;
use TAP::Parser::YAMLish::Reader ();
use TAP::Parser::YAMLish::Writer ();

use vars qw($VERSION);

use constant IS_WIN32 => ( $^O =~ /^(MS)?Win32$/ );
use constant NEED_GLOB => IS_WIN32;

=head1 NAME

App::Prove::State - State storage for the C<prove> command.

=head1 VERSION

Version 3.04

=cut

$VERSION = '3.04';

=head1 DESCRIPTION

The C<prove> command supports a C<--state> option that instructs it to
store persistent state across runs. This module implements that state
and the operations that may be performed on it.

=head1 SYNOPSIS

    # Re-run failed tests
    $ prove --state=fail,save -rbv

=cut

=head1 METHODS

=head2 Class Methods

=head3 C<new>

=cut

sub new {
    my $class = shift;
    my %args = %{ shift || {} };

    my $self = bless {
        tests => {},
        seq   => 1,
        store => delete $args{store},
    }, $class;

    if ( defined( my $store = $self->{store} ) ) {
        $self->load($store);
    }

    return $self;
}

sub DESTROY {
    my $self = shift;
    if ( defined( my $store = $self->{store} ) ) {
        $self->save($store);
    }
}

=head2 Instance Methods

=head3 C<apply_switch>

Apply a list of switch options to the state.

=cut

sub apply_switch {
    my $self = shift;
}

=head3 C<get_tests>

Given a list of args get the names of tests that should run

=cut

sub get_tests {
    my $self    = shift;
    my $recurse = shift;
    my @argv    = @_;
    my ( @tests, %seen );

    unless (@argv) {
        croak q{No tests named and 't' directory not found}
          unless -d 't';
        @argv = 't';
    }

    # Do globbing on Win32.
    @argv = map { glob "$_" } @argv if NEED_GLOB;

    for my $arg (@argv) {
        if ( '-' eq $arg ) {
            push @argv => <STDIN>;
            chomp(@argv);
            next;
        }

        push @tests, sort grep { !$seen{$_}++ } (
              -d $arg
            ? $recurse
                  ? $self->_expand_dir_recursive($arg)
                  : glob( File::Spec->catfile( $arg, '*.t' ) )
            : $arg
        );
    }
    return @tests;
}

sub _expand_dir_recursive {
    my ( $self, $dir ) = @_;

    my @tests;
    find(
        {   follow => 1,      #21938
            wanted => sub {
                -f 
                  && /\.t$/
                  && push @tests => $File::Find::name;
              }
        },
        $dir
    );
    return @tests;
}

=head3 C<observe_test>

Store the results of a test.

=cut

sub observe_test {
    my ( $self, $test, $parser ) = @_;
    $self->_record_test( $test, scalar( $parser->failed ), time() );
}

# Store:
#     last fail time
#     last pass time
#     last run time
#     most recent result
#     total failures
#     total passes

sub _record_test {
    my ( $self, $test, $fail, $when ) = @_;
    my $rec = $self->{tests}->{ $test->[0] } ||= {};

    $rec->{seq} = $self->{seq}++;

    $rec->{last_run_time} = $when;
    $rec->{last_result}   = $fail;

    if ($fail) {
        $rec->{total_failures}++;
        $rec->{last_fail_time} = $when;
    }
    else {
        $rec->{total_passes}++;
        $rec->{last_pass_time} = $when;
    }
}

=head3 C<save>

Write the state to a file.

=cut

sub save {
    my ( $self, $name ) = @_;
    my $writer = TAP::Parser::YAMLish::Writer->new;
    local *FH;
    open FH, ">$name" or croak "Can't write $name ($!)";
    $writer->write( $self->{tests} || {}, \*FH );
    close FH;
}

=head3 C<load>

Load the state from a file

=cut

sub load {
    my ( $self, $name ) = @_;
    my $reader = TAP::Parser::YAMLish::Reader->new;
    local *FH;
    open FH, "<$name" or croak "Can't write $name ($!)";
    $self->{tests} = $reader->read(
        sub {
            my $line = <FH>;
            defined $line && chomp $line;
            return $line;
        }
    );

    # $writer->write( $self->{tests} || {}, \*FH );
    close FH;
    $self->_regen_seq;
}

sub _regen_seq {
    my $self = shift;
    for my $rec ( values %{ $self->{tests} || {} } ) {
        $self->{seq} = $rec->{seq} + 1
          if defined $rec->{seq} && $rec->{seq} >= $self->{seq};
    }
}
