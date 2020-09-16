package TAP::Parser::Iterator::Process::Unix;

use strict;
use warnings;

use IO::Handle;

use base 'TAP::Parser::Iterator::Process';

use constant IS_WIN32 => !!( $^O =~ /^(MS)?Win32$/ );

=head1 NAME

TAP::Parser::Iterator::Process::Unix - Unix-y process-based TAP sources

=head1 VERSION

Version 3.35

=cut

our $VERSION = '3.35';

=head1 DESCRIPTION

This class implements a process iterator for Unix type OSes using only core
modules.  It is also used as a fallback on Windows if the Windows process
iterator can't be used.  This module shouldn't be used directly, create
L<TAP::Parser::Iterator::Process> objects instead which picks Windows or Unix.

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

sub _initialize {
    my ( $self, $args ) = @_;

    my @command = @{ delete $args->{command} || [] }
      or die "Must supply a command to execute";

    $self->{command} = [@command];

    # Private. Used to frig with chunk size during testing.
    my $chunk_size = delete $args->{_chunk_size} || 65536;

    my $merge = delete $args->{merge};
    my ( $pid, $err, $sel );

    if ( my $setup = delete $args->{setup} ) {
        $setup->(@command);
    }

    my $out = IO::Handle->new;

    if ( $self->_use_open3 ) {

        # HOTPATCH {{{
        my $xclose = \&IPC::Open3::xclose;
        no warnings;
        local *IPC::Open3::xclose = sub {
            my $fh = shift;
            no strict 'refs';
            return if ( fileno($fh) == fileno(STDIN) );
            $xclose->($fh);
        };

        # }}}

        if (IS_WIN32) {
            $err = $merge ? '' : '>&STDERR';
            eval {
                $pid = IPC::Open3::open3(
                    '<&STDIN', $out, $merge ? '' : $err,
                    @command
                );
            };
            die "Could not execute (@command): $@" if $@;
            if ( $] >= 5.006 ) {
                binmode($out, ":crlf");
            }
        }
        else {
            $err = $merge ? '' : IO::Handle->new;
            eval { $pid = IPC::Open3::open3( '<&STDIN', $out, $err, @command ); };
            die "Could not execute (@command): $@" if $@;
            $sel = $merge ? undef : IO::Select->new( $out, $err );
        }
    }
    else {
        $err = '';
        my $command
          = join( ' ', map { $_ =~ /\s/ ? qq{"$_"} : $_ } @command );
        open( $out, "$command|" )
          or die "Could not execute ($command): $!";
    }

    $self->{out}        = $out;
    $self->{err}        = $err;
    $self->{sel}        = $sel;
    $self->{pid}        = $pid;
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

    if ( $self->{sel} ) {
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
        package TAP::Parser::Iterator::Process::Unix;
    }
    else {
        if ( $] >= 5.008 ) {
            eval 'binmode($self->{out}, ":utf8")';
        }
    }

}

##############################################################################

sub _next {
    my $self = shift;

    if ( my $out = $self->{out} ) {
        if ( my $sel = $self->{sel} ) {
            my $err        = $self->{err};
            my @buf        = ();
            my $partial    = '';                    # Partial line
            my $chunk_size = $self->{chunk_size};
            return sub {
                return shift @buf if @buf;

                READ:
                while ( my @ready = $sel->can_read ) {
                    for my $fh (@ready) {
                        my $got = sysread $fh, my ($chunk), $chunk_size;

                        if ( $got == 0 ) {
                            $sel->remove($fh);
                        }
                        elsif ( $fh == $err ) {
                            print STDERR $chunk;    # echo STDERR
                        }
                        else {
                            $chunk   = $partial . $chunk;
                            $partial = '';

                            # Make sure we have a complete line
                            unless ( substr( $chunk, -1, 1 ) eq "\n" ) {
                                my $nl = rindex $chunk, "\n";
                                if ( $nl == -1 ) {
                                    $partial = $chunk;
                                    redo READ;
                                }
                                else {
                                    $partial = substr( $chunk, $nl + 1 );
                                    $chunk = substr( $chunk, 0, $nl );
                                }
                            }

                            push @buf, split /\n/, $chunk;
                            return shift @buf if @buf;
                        }
                    }
                }

                # Return partial last line
                if ( length $partial ) {
                    my $last = $partial;
                    $partial = '';
                    return $last;
                }

                $self->_finish;
                return;
            };
        }
        else {
            return sub {
                if ( defined( my $line = <$out> ) ) {
                    chomp $line;
                    return $line;
                }
                $self->_finish;
                return;
            };
        }
    }
    else {
        return sub {
            $self->_finish;
            return;
        };
    }
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

sub get_select_handles {
    my $self = shift;
    return grep $_, ( $self->{out}, $self->{err} );
}

1;

=head1 ATTRIBUTION

This is the original implementation of L<TAP::Parser::Iterator::Process>.

=head1 SEE ALSO

L<TAP::Parser::Iterator::Process>,
L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,

=cut

