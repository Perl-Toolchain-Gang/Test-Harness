package TAP::Parser::Iterator::Process;

use strict;
use warnings;

use Config;
use Win32::APipe;

use base 'TAP::Parser::Iterator';

use constant IS_WIN32 => !!( $^O =~ /^(MS)?Win32$/ );

=head1 NAME

TAP::Parser::Iterator::Process - Iterator for process-based TAP sources

=head1 VERSION

Version 3.35

=cut

our $VERSION = '3.35';

=head1 SYNOPSIS

  use TAP::Parser::Iterator::Process;
  my %args = (
   command  => ['python', 'setup.py', 'test'],
   merge    => 1,
   setup    => sub { ... },
   teardown => sub { ... },
  );
  my $it   = TAP::Parser::Iterator::Process->new(\%args);
  my $line = $it->next;

=head1 DESCRIPTION

This is a simple iterator wrapper for executing external processes, used by
L<TAP::Parser>.  Unless you're writing a plugin or subclassing, you probably
won't need to use this module directly.

=head1 METHODS

=head2 Class Methods

=head3 C<new>

Create an iterator.  Expects one argument containing a hashref of the form:

   command  => \@command_to_execute
   merge    => $attempt_merge_stderr_and_stdout?
   setup    => $callback_to_setup_command
   teardown => $callback_to_teardown_command

Tries to uses L<IPC::Open3> & L<IO::Select> to communicate with the spawned
process if they are available.  Falls back onto C<open()>.

=head2 Instance Methods

=head3 C<next>

Iterate through the process output, of course.

=head3 C<next_raw>

Iterate raw input without applying any fixes for quirky input syntax.

=head3 C<wait>

Get the wait status for this iterator's process.

=head3 C<exit>

Get the exit status for this iterator's process.

=cut

{

    no warnings 'uninitialized';
       # get around a catch22 in the test suite that causes failures on Win32:
    local $SIG{__DIE__} = undef;
    eval { require POSIX; &POSIX::WEXITSTATUS(0) };
    if ($@) {
        *_wait2exit = sub { $_[1] >> 8 };
    }
    else {
        *_wait2exit = sub { POSIX::WEXITSTATUS( $_[1] ) }
    }
}

sub _use_open3 {
    return unless $Config{d_fork} || IS_WIN32;
    for my $module (qw( IPC::Open3 IO::Select )) {
        eval "use $module";
        return if $@;
    }
    return 1;
}

{
    my $got_unicode;

    sub _get_unicode {
        return $got_unicode if defined $got_unicode;
        eval 'use Encode qw(decode_utf8);';
        $got_unicode = $@ ? 0 : 1;

    }
}

# new() implementation supplied by TAP::Object

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

=head3 C<handle_unicode>

Upgrade the input stream to handle UTF8.

=cut

sub handle_unicode {
    my $self = shift;

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

}

##############################################################################

sub wait { shift->{wait} }
sub exit { shift->{exit} }

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

sub next_raw {
    my $self = shift;
    return ( $self->{_next} ||= $self->_next )->();
}

sub _finish {
    my $self = shift;

    my $status = $?;

    # Avoid circular refs
    $self->{_next} = sub {return}
      if $] >= 5.006;

    # If we have a subprocess we need to wait for it to terminate
    if ( defined $self->{pid} ) {
        if ( $self->{pid} == waitpid( $self->{pid}, 0 ) ) {
            $status = $?;
        }
    }

    ( delete $self->{out} )->close if $self->{out};

    # If we have an IO::Select we also have an error handle to close.
    if ( $self->{sel} ) {
        ( delete $self->{err} )->close;
        delete $self->{sel};
    }
    else {
        $status = $?;
    }

    # Sometimes we get -1 on Windows. Presumably that means status not
    # available.
    $status = 0 if IS_WIN32 && $status == -1;

    $self->{wait} = $status;
    $self->{exit} = $self->_wait2exit($status);

    if ( my $teardown = $self->{teardown} ) {
        $teardown->();
    }

    return $self;
}

=head3 C<get_select_handles>

Return a list of filehandles that may be used upstream in a select()
call to signal that this Iterator is ready. Iterators that are not
handle based should return an empty list.

=cut

sub get_select_handles {
    return;
}

1;

=head1 ATTRIBUTION

Originally ripped off from L<Test::Harness>.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,

=cut

