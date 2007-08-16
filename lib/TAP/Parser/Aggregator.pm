package TAP::Parser::Aggregator;

use strict;
use vars qw($VERSION);

=head1 NAME

TAP::Parser::Aggregator - Aggregate TAP::Parser results.

=head1 VERSION

Version 0.53

=cut

$VERSION = '0.53';

=head1 SYNOPSIS

    use TAP::Parser::Aggregator;

    my $aggregate = TAP::Parser::Aggregator->new;
    $aggregate->add( 't/00-load.t', $load_parser );
    $aggregate->add( 't/10-lex.t',  $lex_parser  );
    
    my $summary = <<'END_SUMMARY';
    Passed:  %s
    Failed:  %s
    Unexpectedly succeeded: %s
    END_SUMMARY
    printf $summary, 
           scalar $aggregate->passed, 
           scalar $aggregate->failed,
           scalar $aggregate->todo_passed;

=head1 DESCRIPTION

C<TAP::Parser::Aggregator> is a simple class which takes parser objects and
allows reporting of aggregate results.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

 my $aggregate = TAP::Parser::Aggregator->new;

Returns a new C<TAP::Parser::Aggregator> object.

=cut

my %SUMMARY_METHOD_FOR;

BEGIN {
    %SUMMARY_METHOD_FOR = map { $_ => $_ } qw(
      failed
      parse_errors
      passed
      skipped
      todo
      todo_passed
      total
      wait
      exit
    );
    $SUMMARY_METHOD_FOR{total} = 'tests_run';

    foreach my $method ( keys %SUMMARY_METHOD_FOR ) {
        next if 'total' eq $method;
        no strict 'refs';
        *$method = sub {
            my $self = shift;
            return wantarray
              ? @{ $self->{"descriptions_for_$method"} }
              : $self->{$method};
        };
    }
}

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    $self->_initialize;
    return $self;
}

sub _initialize {
    my ($self) = @_;
    $self->{parser_for}  = {};
    $self->{parse_order} = [];
    foreach my $summary ( keys %SUMMARY_METHOD_FOR ) {
        $self->{$summary} = 0;
        next if 'total' eq $summary;
        $self->{"descriptions_for_$summary"} = [];
    }
    return $self;
}

##############################################################################

=head2 Instance Methods

=head3 C<add>

  $aggregate->add( $description, $parser );

Takes two arguments, the description of the TAP source (usually a test file
name, but it doesn't have to be) and a L<TAP::Parser> object.

Trying to reuse a description is a fatal error.

=cut

sub add {
    my ( $self, $description, $parser ) = @_;
    if ( exists $self->{parser_for}{$description} ) {
        $self->_croak("You already have a parser for ($description)");
    }
    push @{ $self->{parse_order} } => $description;
    $self->{parser_for}{$description} = $parser;

    while ( my ( $summary, $method ) = each %SUMMARY_METHOD_FOR ) {
        if ( my $count = $parser->$method() ) {
            $self->{$summary} += $count;
            push @{ $self->{"descriptions_for_$summary"} } => $description;
        }
    }

    return $self;
}

##############################################################################

=head3 C<parsers>

  my $count   = $aggregate->parsers;
  my @parsers = $aggregate->parsers;
  my @parsers = $aggregate->parsers(@descriptions);

In scalar context without arguments, this method returns the number of parsers
aggregated.  In list context without arguments, returns the parsers in the
order they were added.

If arguments are used, these should be a list of descriptions used with the
C<add> method.  Returns an array in list context or an array reference in
scalar context.  The array contents will the requested parsers in the order
they were listed in the argument list.  

Passing in an unknown description is a fatal error.  

=cut

sub parsers {
    my $self = shift;
    return $self->_get_parsers(@_) if @_;
    my $descriptions = $self->{parse_order};
    my @parsers      = @{ $self->{parser_for} }{@$descriptions};

    # Note:  Because of the way context works, we must assign the parsers to
    # the @parsers array or else this method does not work as documented.
    return @parsers;
}

sub _get_parsers {
    my ( $self, @descriptions ) = @_;
    my @parsers;
    foreach my $description (@descriptions) {
        $self->_croak("A parser for ($description) could not be found")
          unless exists $self->{parser_for}{$description};
        push @parsers => $self->{parser_for}{$description};
    }
    return wantarray ? @parsers : \@parsers;
}

##############################################################################

=head2 Summary methods

Each of the following methods will return the total number of corresponding
tests if called in scalar context.  If called in list context, returns the
descriptions of the parsers which contain the corresponding tests (see C<add>
for an explanation of description.

=over 4

=item * failed

=item * parse_errors

=item * passed

=item * skipped

=item * todo

=item * todo_passed

=item * wait

=item * exit

=back

For example, to find out how many tests unexpectedly succeeded (TODO tests
which passed when they shouldn't):

 my $count        = $aggregate->todo_passed;
 my @descriptions = $aggregate->todo_passed;

Note that C<wait> and C<exit> are the totals of the wait and exit
statuses of each of the tests. These values are totalled only to provide
a true value if any of them are non-zero.

=cut

##############################################################################

=head3 C<total>

  my $tests_run = $aggregate->total;

Returns the total number of tests run.

=cut

sub total { shift->{total} }

##############################################################################

=head3 C<has_problems>

  if ( $parser->has_problems ) {
      ...
  }

This is a 'catch-all' method which returns true if any tests have currently
failed, any TODO tests unexpectedly succeeded, or any parse errors.

=cut

sub has_problems {
    my $self = shift;
    return $self->failed
      || $self->todo_passed
      || $self->parse_errors
      || $self->exit
      || $self->wait;
}

##############################################################################

=head3 C<todo_failed>

  # deprecated in favor of 'todo_passed'.  This method was horribly misnamed.

This was a badly misnamed method.  It indicates which TODO tests unexpectedly
succeeded.  Will now issue a warning and call C<todo_passed>.

=cut

sub todo_failed {
    warn
      '"todo_failed" is deprecated.  Please use "todo_passed".  See the docs.';
    goto &todo_passed;
}

sub _croak {
    my $proto = shift;
    require Carp;
    Carp::croak(@_);
}

1;
