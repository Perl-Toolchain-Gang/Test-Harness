package TAP::Parser::Iterator::Stream;

use strict;
use vars qw($VERSION);

=head1 NAME

TAP::Parser::Iterator::Stream - Internal TAP::Parser Iterator

=head1 VERSION

Version 0.52

=cut

$VERSION = '0.52';

=head1 SYNOPSIS

  use TAP::Parser::Iterator;
  my $it = TAP::Parser::Iterator::Stream->new(\*TEST);

  my $line = $it->next;

Originally ripped off from C<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for filehandles.

=head2 new()

Create an iterator.

=head2 next()

Iterate through it, of course.

=head2 next_raw()

Iterate raw input without applying any fixes for quirky input syntax.

=head2 wait()

Get the wait status for this iterator. Always returns zero.

=head2 exit()

Get the exit status for this iterator. Always returns zero.

=cut

sub new {
    my ( $class, $thing ) = @_;
    bless {
        fh => $thing,
    }, $class;
}

##############################################################################

sub wait { shift->wait }
sub exit { shift->{fh} ? 0 : () }

sub next_raw {
    my $self = shift;
    my $fh   = $self->{fh};

    if ( defined( my $line = <$fh> ) ) {
        chomp $line;
        return $line;
    }
    else {
        $self->_finish;
        return;
    }
}

sub next {
    my $self = shift;
    my $line = $self->next_raw;

    # vms nit:  When encountering 'not ok', vms often has the 'not' on a line
    # by itself:
    #   not
    #   ok 1 - 'I hate VMS'
    if ( defined $line && $line =~ /^\s*not\s*$/ ) {
        $line .= ( $self->next_raw || '' );
    }
    return $line;
}

sub _finish {
    my $self = shift;
    close delete $self->{fh};
}

1;
