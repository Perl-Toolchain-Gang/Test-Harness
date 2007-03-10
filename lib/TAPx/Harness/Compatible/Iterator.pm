package TAP::Harness::Compatible::Iterator;

use strict;
use vars qw($VERSION);
use TAP::Parser::Iterator;

$VERSION = '0.51';

=head1 NAME

TAP::Harness::Compatible::Iterator - Internal TAP::Harness::Compatible Iterator

=head1 SYNOPSIS

  use TAP::Harness::Compatible::Iterator;
  my $it = TAP::Harness::Compatible::Iterator->new(\*TEST);
  my $it = TAP::Harness::Compatible::Iterator->new(\@array);

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

    return bless { iter => TAP::Parser::Iterator->new($thing) }, $class;
}

sub next {
    my $next = shift->{iter}->next_raw;
    return defined $next ? "$next\n" : $next;
}

1;
