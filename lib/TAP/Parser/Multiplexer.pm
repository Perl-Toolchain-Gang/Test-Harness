package TAP::Parser::Multiplexer;

use strict;
use warnings;

use IO::Select;

use base 'TAP::Object';

use constant IS_WIN32 => $^O =~ /^(MS)?Win32$/;
use constant IS_VMS => $^O eq 'VMS';
use constant SELECT_OK => !( IS_VMS || IS_WIN32 );

=head1 NAME

TAP::Parser::Multiplexer - Multiplex multiple TAP::Parsers

=head1 VERSION

Version 3.42

=cut

our $VERSION = '3.42';

=head1 SYNOPSIS

    use TAP::Parser::Multiplexer;

    my $mux = TAP::Parser::Multiplexer->new;
    $mux->add( $parser1, $stash1 );
    $mux->add( $parser2, $stash2 );
    while ( my ( $parser, $stash, $result ) = $mux->next ) {
        # do stuff
    }

=head1 DESCRIPTION

C<TAP::Parser::Multiplexer> gathers input from multiple TAP::Parsers.
Internally it calls select on the input file handles for those parsers
to wait for one or more of them to have input available.

See L<TAP::Harness> for an example of its use.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

    my $mux = TAP::Parser::Multiplexer->new;

Returns a new C<TAP::Parser::Multiplexer> object.

=cut

# new() implementation supplied by TAP::Object

sub _initialize {
    my $self = shift;
    $self->{select} = IO::Select->new;
    $self->{avid}   = [];                # Parsers that can't select
    $self->{count}  = 0;
    $self->{w32_count}  = 0;
    return $self;
}

##############################################################################

=head2 Instance Methods

=head3 C<add>

  $mux->add( $parser, $stash );

Add a TAP::Parser to the multiplexer. C<$stash> is an optional opaque
reference that will be returned from C<next> along with the parser and
the next result.

=cut

sub add {
    my ( $self, $parser, $stash ) = @_;
    my $iterator;

    if ( SELECT_OK && ( my @handles = $parser->get_select_handles ) ) {
        my $sel = $self->{select};

        # We have to turn handles into file numbers here because by
        # the time we want to remove them from our IO::Select they
        # will already have been closed by the iterator.
        my @filenos = map { fileno $_ } @handles;
        for my $h (@handles) {
            $sel->add( [ $h, $parser, $stash, @filenos ] );
        }

        $self->{count}++;
    }
    elsif (IS_WIN32
           && ($iterator = $parser->_iterator)->isa('TAP::Parser::Iterator::Process::Windows')) {
        #By this point the Win32 proc was already started.
        #When the parser obj is new()ed, the proc starts. No read events on a
        #PP level have occured yet (there is an async read in progress tho)
        $iterator->opaque([ $parser, $stash ]);
        #Iterator::Process::Windows obj is now push-only, pulls are fatal
        #Allowing reads on a async queue multiplexer registered iterater can
        #result in some procs getting much more read/data poping off the queue
        #than other procs leadings to stalls/blocks in other procs randomly.
        #Also anti-hang "you can't next() when there is no work" die sometimes
        #occurs if multiplexerd I::P::W obj executes a queue pop in
        #I::P::W::next_raw() queue although that is fixable in theory with
        #additional global state. So just never have 2 competing event loops.
        $iterator->{disable_read} = 1;
        $self->{w32_count}++;
    }
    else {
        push @{ $self->{avid} }, [ $parser, $stash ];
    }
}

=head3 C<parsers>

  my $count   = $mux->parsers;

Returns the number of parsers. Parsers are removed from the multiplexer
when their input is exhausted.

=cut

sub parsers {
    my $self = shift;
    return $self->{count} + $self->{w32_count} + scalar @{ $self->{avid} };
}

sub _iter {
    my $self = shift;

    my $sel   = $self->{select};
    my $avid  = $self->{avid};
    my @ready = ();
    my $iterator;

    return sub {

        # Drain all the non-selectable parsers first
        if (@$avid) {
            my ( $parser, $stash ) = @{ $avid->[0] };
            my $result = $parser->next;
            shift @$avid unless defined $result;
            return ( $parser, $stash, $result );
        }
        if ($self->{w32_count}) {
            {
                my $chunk; #either a string or a hash ref with end of stream info
                #keep pulling TAP lines out of same iterator until iterator's
                #buffer exhausted
                unless($iterator) {
                    $iterator = Win32::APipe::next($chunk);
                    #not enough data, pretend we never saw it and wait for
                    #another data block iterator
                    undef($iterator), redo unless $iterator->add_chunk($chunk);
                }
                my ( $parser, $stash ) = @{$iterator->opaque};
                #sanity test/assert, maybe remove one day
                die 'atleast 1 line should already exist, the $parser->next() is non-blocking'
                    if @{$iterator->{buf}} == 0 && !$iterator->{done};
                my $result = $parser->next;

                #nuke circ ref if end of stream
                unless (defined $result){
                    $iterator->opaque(undef);
                    $self->{w32_count}--;
                    undef($iterator);
                }
                #iterator is out of data, but not finished, needs another read
                elsif (@{$iterator->{buf}} == 0) {
                    undef($iterator);
                }
                return ( $parser, $stash, $result );
            }
        }

        unless (@ready) {
            return unless $sel->count;
            @ready = $sel->can_read;
        }

        my ( $h, $parser, $stash, @handles ) = @{ shift @ready };
        my $result = $parser->next;

        unless ( defined $result ) {
            $sel->remove(@handles);
            $self->{count}--;

            # Force another can_read - we may now have removed a handle
            # thought to have been ready.
            @ready = ();
        }

        return ( $parser, $stash, $result );
    };
}

=head3 C<next>

Return a result from the next available parser. Returns a list
containing the parser from which the result came, the stash that
corresponds with that parser and the result.

    my ( $parser, $stash, $result ) = $mux->next;

If C<$result> is undefined the corresponding parser has reached the end
of its input (and will automatically be removed from the multiplexer).

When all parsers are exhausted an empty list will be returned.

    if ( my ( $parser, $stash, $result ) = $mux->next ) {
        if ( ! defined $result ) {
            # End of this parser
        }
        else {
            # Process result
        }
    }
    else {
        # All parsers finished
    }

=cut

sub next {
    my $self = shift;
    return ( $self->{_iter} ||= $self->_iter )->();
}

=head1 See Also

L<TAP::Parser>

L<TAP::Harness>

=cut

1;
