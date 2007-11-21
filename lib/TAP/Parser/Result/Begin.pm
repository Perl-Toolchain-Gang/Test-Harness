package TAP::Parser::Result::Begin;

use strict;

use vars qw($VERSION @ISA);
use TAP::Parser::Result;
@ISA = 'TAP::Parser::Result';

use vars qw($VERSION);

=head1 NAME

TAP::Parser::Result::Begin - Test result token.

=head1 VERSION

Version 3.04

=cut

$VERSION = '3.04';

=head1 DESCRIPTION

This is a subclass of L<TAP::Parser::Result>.  A token of this class will be
returned if a begin directive is encountered.

=head1 OVERRIDDEN METHODS

This class is the workhorse of the L<TAP::Parser> system.  Most TAP lines will
be test lines and if C<< $result->is_test >>, then you have a bunch of methods
at your disposal.

=head2 Instance Methods

=cut

##############################################################################

=head3 C<number>

  my $test_number = $result->number;

Returns the number of the begin directive.

=cut

sub number { shift->{test_num} }

sub _number {
    my ( $self, $number ) = @_;
    $self->{test_num} = $number;
}

##############################################################################

=head3 C<description>

  my $description = $result->description;

Returns the description of the test, if any.  This is the portion after the
test number but before the directive.

=cut

sub description { shift->{description} }

##############################################################################

1;
