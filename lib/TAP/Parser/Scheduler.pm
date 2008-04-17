package TAP::Parser::Scheduler;

use strict;
use vars qw($VERSION);
use Carp;
use TAP::Parser::Scheduler::Job;
use TAP::Parser::Scheduler::Spinner;

=head1 NAME

TAP::Parser::Scheduler - Schedule tests during parallel testing

=head1 VERSION

Version 3.11

=cut

$VERSION = '3.11';

=head1 SYNOPSIS

    use TAP::Parser::Scheduler;

=head1 DESCRIPTION

=head1 METHODS

=head2 Class Methods

=head3 C<new>

    my $sched = TAP::Parser::Scheduler->new;

Returns a new C<TAP::Parser::Scheduler> object.

=cut

sub new {
    my $class = shift;

    croak "Need a number of key, value pairs" if @_ % 2;

    my %args  = @_;
    my $tests = delete $args{tests} || croak "Need a 'tests' argument";
    my $rules = delete $args{rules} || { par => '*' };

    croak "Unknown arg(s): ", join ', ', sort keys %args
      if keys %args;

    # Turn any simple names into a name, description pair. TODO: Maybe
    # construct jobs here?
    my $self = bless {}, $class;

    $self->_set_rules( $rules, $tests );

    return $self;
}

# Build the scheduler data structure.
#
# SCHEDULER-DATA ::= JOB
#                ||  ARRAY OF ARRAY OF SCHEDULER-DATA
#
# The nested arrays are the key to scheduling. The outer array contains
# a list of things that may be executed in parallel. Whenever an
# eligible job is sought any element of the outer array that is ready to
# execute can be selected. The inner arrays represent sequential
# execution. They can only proceed when the first job is ready to run.

sub _set_rules {
    my ( $self, $rules, $tests ) = @_;
    $self->{schedule} = $self->_rule_clause(
        $rules,
        [   map { TAP::Parser::Scheduler::Job->new(@$_) }
              map { 'ARRAY' eq ref $_ ? $_ : [ $_, $_ ] } @$tests
        ]
    );

    # TODO: If any tests are left add them as a parallel block at the end of
    # the run.
}

sub _rule_clause {
    my ( $self, $rule, $tests ) = @_;
    croak 'Rule clause must be a hash'
      unless 'HASH' eq ref $rule;

    my @type = keys %$rule;
    croak 'Rule clause must have exactly one key'
      unless @type == 1;

    my %handlers = (
        par => sub {
            [ map { [$_] } @_ ];
        },
        seq => sub { [ [@_] ] },
    );

    my $handler = $handlers{ $type[0] }
      || croak 'Unknown scheduler type: ', $type[0];
    my $val = $rule->{ $type[0] };

    return $handler->(
        map {
            'HASH' eq ref $_
              ? $self->_rule_clause( $_, $tests )
              : $self->_expand( $_, $tests )
          } 'ARRAY' eq ref $val ? @$val : $val
    );
}

sub _expand {
    my ( $self, $name, $tests ) = @_;

    $name =~ s{(.)}{
        $1 eq '?' ? '.'
      : $1 eq '*' ? '.*'
      :             quotemeta($1);
    }gex;

    my $pattern = qr{^$name$};
    my @match   = ();

    for ( my $ti = 0; $ti < @$tests; $ti++ ) {
        if ( $tests->[$ti]->filename =~ $pattern ) {
            push @match, splice @$tests, $ti, 1;
            $ti--;
        }
    }

    return @match;
}

=head3 C<get_all>

Get a list of all remaining tests.

=cut

sub get_all {
    my $self = shift;
    $self->_gather( $self->{schedule} );
}

sub _gather {
    my ( $self, $rule ) = @_;
    return unless defined $rule;
    return $rule unless 'ARRAY' eq ref $rule;
    return map { $self->_gather($_) } grep {defined} map {@$_} @$rule;
}

=head3 C<get_job>

Return the next available job or C<undef> if none are available. Returns
a C<TAP::Parser::Scheduler::Spinner> if the scheduler still has pending
jobs but none are available to run right now.

=cut

sub get_job {
    my $self = shift;
    my @jobs = $self->_find_next_job( $self->{schedule} );
    return $jobs[0] if @jobs;

    # TODO: This isn't very efficient...
    return TAP::Parser::Scheduler::Spinner->new
      if $self->get_all;

    return;
}

sub _find_next_job {
    my ( $self, $rule ) = @_;

    # return unless defined $rule;
    # return $rule unless 'ARRAY' eq ref $rule;

    for my $seq (@$rule) {
        if ( @$seq && defined $seq->[0] && 'ARRAY' ne ref $seq->[0] ) {
            my $job = splice @$seq, 0, 1, undef;
            $job->on_finish( sub { splice @$seq, 0, 1 } );
            return $job;
        }
    }

    for my $seq (@$rule) {
        if ( @$seq && defined $seq->[0] && 'ARRAY' eq ref $seq->[0] ) {
            if ( my @jobs = $self->_find_next_job( $seq->[0] ) ) {
                return @jobs;
            }
        }
    }

    return;
}

=head3 C<get_job_iterator>

Get a code reference that will return a stream of
C<TAP::Parser::Scheduler::Job>s.

=cut

# sub get_job_iterator {
#     my $self  = shift;
#     my @tests = $self->get_all;
#     return sub { shift @tests };
# }

sub get_job_iterator {
    my $self = shift;
    return sub { $self->get_job };
}

1;
