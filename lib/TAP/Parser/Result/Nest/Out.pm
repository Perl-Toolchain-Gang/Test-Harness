package TAP::Parser::Result::Nest::Out;

use strict;

use vars qw($VERSION @ISA);
use TAP::Parser::Result;
@ISA = 'TAP::Parser::Result';

=head1 NAME

TAP::Parser::Result::Nest::Out - End of a nested block

=head1 VERSION

Version 3.17

=cut

$VERSION = '3.17';

=head1 DESCRIPTION

This is a subclass of L<TAP::Parser::Result>.  A token of this class will be
returned when the nesting level decreases.

=head1 OVERRIDDEN METHODS

Mainly listed here to shut up the pitiful screams of the pod coverage tests.
They keep me awake at night.

=over 4

=item * C<as_string>

=item * C<raw>

=back

=cut

1;
