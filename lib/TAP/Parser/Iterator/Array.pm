package TAP::Parser::Iterator::Array;

use strict;
use TAP::Parser::Iterator;
use vars qw($VERSION @ISA);
@ISA     = 'TAP::Parser::Iterator';

=head1 NAME

TAP::Parser::Iterator::Array - Internal TAP::Parser Iterator

=head1 VERSION

Version 0.52

=cut

$VERSION = '0.52';

=head1 SYNOPSIS

  use TAP::Parser::Iterator::Array;
  my $it = TAP::Parser::Iterator->new(\@array);

  my $line = $it->next;

Originally ripped off from C<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for arrays.

=head2 new()

Create an iterator.

=head2 next()

Iterate through it, of course.

=head2 next_raw()

Iterate raw input without applying any fixes for quirky input syntax.

=head2 wait()

Get the wait status for this iterator. For an array iterator this will always be zero.

=head2 exit()

Get the exit status for this iterator. For an array iterator this will always be zero.

=cut

sub new {
    my ( $class, $thing ) = @_;
    chomp @$thing;
    bless {
        idx   => 0,
        array => $thing,
        exit  => undef,
    }, $class;
}

sub wait { shift->exit }

sub exit {
    my $self = shift;
    return 0 if $self->{idx} >= @{ $self->{array} };
    return;
}

sub next {
    my $self = shift;
    return $self->{array}->[ $self->{idx}++ ];
}

sub next_raw { shift->next }

1;
