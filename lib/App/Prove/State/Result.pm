package App::Prove::State::Result;

use strict;
use warnings;

use vars qw($VERSION);

=head1 NAME

App::Prove::State::Result - Individual test suite results.

=head1 VERSION

Version 3.14

=cut

$VERSION = '3.14';

=head1 DESCRIPTION

The C<prove> command supports a C<--state> option that instructs it to
store persistent state across runs. This module encapsulates the results for a
single test suite run.

=head1 SYNOPSIS

    # Re-run failed tests
    $ prove --state=fail,save -rbv

=cut

=head1 METHODS

=head2 Class Methods

=head3 C<new>

=cut

sub new {
    my ( $class, $arg_for ) = @_;
    $arg_for ||= {};
    bless $arg_for => $class;
}

=head3 C<generation>

Getter/setter for the "generation" of the test suite run.  The first
generation is 1 (one) and subsequent generations are 2, 3, etc.

=cut

sub generation {
    my $self = shift;
    if (@_) {
        $self->{generation} = shift;
        return $self;
    }
    return $self->{generation} || 0;
}

=head3 C<tests>

Returns the tests for a give generation.  This is a hashref of a hash,
depending on context called.  The keys to the hash are the individual test
names and the value is a hashref with various interesting values.  Each k/v
pair might resemble something like this:

 't/foo.t' => {
    elapsed        => '0.0428488254547119',
    gen            => '7',
    last_pass_time => '1219328376.07815',
    last_result    => '0',
    last_run_time  => '1219328376.07815',
    last_todo      => '0',
    mtime          => '1191708862',
    seq            => '192',
    total_passes   => '6',
  }

=cut

sub tests {
    my $self = shift;
    if (@_) {
        $self->{tests} = shift;
        return $self;
    }
    my $tests = $self->{tests} || {};
    return wantarray ? %$tests : $tests;
}

=head3 C<num_tests>

Returns the number of tests for a given test suite result.

=cut

sub num_tests { keys %{ shift->{tests} } }

1;
