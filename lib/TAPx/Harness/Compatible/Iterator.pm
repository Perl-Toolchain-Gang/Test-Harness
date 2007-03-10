package TAPx::Harness::Compatible::Iterator;

use strict;
use vars qw($VERSION);
use TAPx::Parser::Iterator;

$VERSION = '0.51';

=head1 NAME

TAPx::Harness::Compatible::Iterator - Internal TAPx::Harness::Compatible Iterator

=head1 SYNOPSIS

  use TAPx::Harness::Compatible::Iterator;
  my $it = TAPx::Harness::Compatible::Iterator->new(\*TEST);
  my $it = TAPx::Harness::Compatible::Iterator->new(\@array);

  my $line = $it->next;

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for arrays and filehandles.

=head2 new()

Create an iterator.

=head2 next()

Iterate through it, of course.

=cut

sub new {
    my ( $class, $thing ) = @_;

    return bless { iter => TAPx::Parser::Iterator->new($thing) }, $class;
}

sub next {
    my $next = shift->{iter}->next_raw;
    return defined $next ? "$next\n" : $next;
}

1;
