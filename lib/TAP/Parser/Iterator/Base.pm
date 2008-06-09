package TAP::Parser::Iterator::Base;

use strict;
use vars qw($VERSION @ISA);

use TAP::Object ();

@ISA = qw(TAP::Object);

=head1 NAME

TAP::Parser::Iterator::Base - Internal base class for TAP::Parser Iterators

=head1 VERSION

Version 3.12

=cut

$VERSION = '3.12';

=head1 SYNOPSIS

  use vars qw(@ISA);
  use TAP::Parser::Iterator::Base ();
  @ISA = qw(TAP::Parser::Iterator::Base);
  sub _initialize {
    # see TAP::Object...
  }

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator base class that defines the iterator API.  See
C<TAP::Parser::Iterator> for a factory class that creates iterators.

=head2 Class Methods

=head3 C<new>

Create an iterator.

=cut

# new() provided by TAP::Object


=head2 Instance Methods

=head3 C<next>

 while ( my $item = $iter->next ) { ... }

Iterate through it, of course.

=head3 C<next_raw>

 while ( my $item = $iter->next_raw ) { ... }

Iterate raw input without applying any fixes for quirky input syntax.

I<Note:> this method is abstract and should be overridden.

=cut

sub next {
    my $self = shift;
    my $line = $self->next_raw;

    # vms nit:  When encountering 'not ok', vms often has the 'not' on a line
    # by itself:
    #   not
    #   ok 1 - 'I hate VMS'
    if ( defined($line) and $line =~ /^\s*not\s*$/ ) {
        $line .= ( $self->next_raw || '' );
    }

    return $line;
}

sub next_raw {
    require Carp;
    my $msg = Carp::longmess('abstract method called directly!');
    $_[0]->_croak( $msg );
}


=head3 C<handle_unicode>

If necessary switch the input stream to handle unicode. This only has
any effect for I/O handle based streams.

The default implementation does nothing.

=cut

sub handle_unicode { }

=head3 C<get_select_handles>

Return a list of filehandles that may be used upstream in a select()
call to signal that this Iterator is ready. Iterators that are not
handle-based should return an empty list.

The default implementation does nothing.

=cut

sub get_select_handles {
    return
}

1;

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,
L<TAP::Parser::Iterator::Array>,
L<TAP::Parser::Iterator::Stream>,
L<TAP::Parser::Iterator::Process>,

=cut

