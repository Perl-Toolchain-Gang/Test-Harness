package TAP::Parser::Iterator::Process::Windows;

use strict;
use warnings;

use Win32::APipe;

use base 'TAP::Parser::Iterator::Process';

=head1 NAME

TAP::Parser::Iterator::Process::Windows - Windows process-based TAP sources

=head1 VERSION

Version 3.35

=cut

our $VERSION = '3.35';

=head1 DESCRIPTION

This class implements an experimental process iterator for Windows.  It
requires L<Win32::APipe> XS module to be installed.  This module shouldn't be
used directly, create L<TAP::Parser::Iterator::Process> objects instead which
picks Windows or Unix.

=cut

sub _initialize {
    my ( $self, $args ) = @_;

    my @command = @{ delete $args->{command} || [] }
      or die "Must supply a command to execute";

    $self->{command} = [@command];
    $self->{buf}     = [];
    $self->{partial} = '';

    # Private. Used to frig with chunk size during testing.
    my $chunk_size = delete $args->{_chunk_size} || 65536;

    my $merge = delete $args->{merge};

    if ( my $setup = delete $args->{setup} ) {
        $setup->(@command);
    }

    my $command = join( ' ', map { $_ =~ /\s/ ? qq{"$_"} : $_ } @command );
    my $err = Win32::APipe::run($command, $self, $merge, $self->{pid});
    die "Could not execute ($command): Win32 Err $err" if $err != 0; #0=ERROR_SUCCESS

    $self->{exit}       = undef;
    $self->{chunk_size} = $chunk_size;

    if ( my $teardown = delete $args->{teardown} ) {
        $self->{teardown} = sub {
            $teardown->(@command);
        };
    }

    return $self;
}

sub handle_unicode {
    my $self = shift;

    package TAP::Parser::Iterator::Process;

    if ( _get_unicode() ) {

        # Make sure our iterator has been constructed and...
        my $next = $self->{_next} ||= $self->_next;

        # ...wrap it to do UTF8 casting
        $self->{_next} = sub {
            my $line = $next->();
            return decode_utf8($line) if defined $line;
            return;
        };
    }
    package TAP::Parser::Iterator::Process::Windows;
}

sub _next {
    my $self = shift;

    return sub {
        #non-blocking quick return of a line
        return shift @{$self->{buf}} if @{$self->{buf}};
        #sanity test against hang forever reading on a finished stream
        return undef if $self->{done};
        my $opaque;

    #a ->next() on any particular Iterator::Process object, pumps
    #events/buffers/lines into ALL Iterator::Process objects until a line is
    #availble for the particular Iterator::Process object

    #if we get random other Iterator::Process objects, we have to process their
    #data buffers and queue it into @{$self->{buf}}, this loop turns the async
    #IO with async reads completing in a random order, into sync IO for the
    #caller, when the caller moves onto other Iterator::Process objects and
    #calls ->next() on those other Iterator::Process objects, ->next() will be
    #non-blocking since @{$self->{buf}} has elements
        do {
            my $chunk;
            READ:
            $opaque = Win32::APipe::next($chunk);
            goto READ unless $opaque->add_chunk($chunk);
        } while ($opaque != $self);

        return shift @{$self->{buf}}
    };
}

# returns true if atleast 1 line was added to @{$self->{buf}}, if false you
# must add another chunk (do another async read) since there wasn't enough data
# or the data happens to not have a newline in it upto this point

sub add_chunk {
    my ($self, $chunk) = @_;
    if(ref($chunk)) {
        $self->{done} = 1;
        #$block->{ExitCode} = 0xc0000005;
        #always return the raw Win32 error code, even tho on unix this will be 0 if a "signal" ended the process
        $self->{exit} = $chunk->{ExitCode}; #this might a negative Win32 STATUS_* code, like STATUS_ACCESS_VIOLATION
        #do we set coredump bit and when?
        $self->{wait} = Win32::APipe::status_to_sig($chunk->{ExitCode});

        if(! $self->{wait}) { #process probably naturally exited
            $self->{wait} = $self->{exit} << 8; #signal zero is implicit here
        }
        if ( my $teardown = $self->{teardown} ) {
            $teardown->();
        }
        #this might be undef or a partial line before the proc abnormally exited
        push @{$self->{buf}}, (length $self->{partial} ? $self->{partial} : undef);
    } else {
        $chunk   = $self->{partial} . $chunk;
        $self->{partial} = '';

        # Make sure we have a complete line
        unless ( substr( $chunk, -1, 2 ) eq "\r\n" ) {
            my $nl = rindex $chunk, "\r\n";
            if ( $nl == -1 ) {
                $self->{partial} = $chunk;
                return 0;
            }
            else {
                $self->{partial} = substr( $chunk, $nl + 2 );
                $chunk = substr( $chunk, 0, $nl );
            }
        }
        push @{$self->{buf}}, split /\r\n/, $chunk;
    }
    return 1;
}

sub get_select_handles {
    return;
}

1;

=head1 SEE ALSO

L<TAP::Parser::Iterator::Process>,
L<TAP::Parser::Iterator::Process::Unix>,
L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,

=cut

