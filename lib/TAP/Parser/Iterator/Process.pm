package TAP::Parser::Iterator::Process;

use strict;

use TAP::Parser::Iterator;

use vars qw($VERSION @ISA);

@ISA = 'TAP::Parser::Iterator';

use Config;
use IO::Handle;

my $IS_WIN32 = ( $^O =~ /^(MS)?Win32$/ );
my $IS_MACOS = ( $^O eq 'MacOS' );
my $IS_VMS   = ( $^O eq 'VMS' );

=head1 NAME

TAP::Parser::Iterator::Process - Internal TAP::Parser Iterator

=head1 VERSION

Version 2.99_02

=cut

$VERSION = '2.99_02';

=head1 SYNOPSIS

  use TAP::Parser::Iterator;
  my $it = TAP::Parser::Iterator::Process->new(@args);

  my $line = $it->next;

Originally ripped off from L<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for processes.

=head2 Class Methods

=head3 C<new>

Create an iterator.

=head2 Instance Methods

=head3 C<next>

Iterate through it, of course.

=head3 C<next_raw>

Iterate raw input without applying any fixes for quirky input syntax.

=head3 C<wait>

Get the wait status for this iterator's process.

=head3 C<exit>

Get the exit status for this iterator's process.

=cut

eval { require POSIX; &POSIX::WEXITSTATUS(0) };
if ($@) {
    *_wait2exit = sub { $_[1] >> 8 };
}
else {
    *_wait2exit = sub { POSIX::WEXITSTATUS( $_[1] ) }
}

sub _use_open3 {
    my $self = shift;
    return unless $Config{d_fork} || $IS_WIN32;
    for my $module (qw( IPC::Open3 IO::Select )) {
        eval "use $module";
        return if $@;
    }
    return 1;
}

sub new {
    my $class = shift;
    my $args  = shift;

    local *DUMMY;

    my @command = @{ delete $args->{command} || [] }
      or die "Must supply a command to execute";

    my $merge = delete $args->{merge};
    my ( $pid, $err, $sel );

    if ( my $setup = delete $args->{setup} ) {
        $setup->(@command);
    }

    my $out = IO::Handle->new;

    if ( $class->_use_open3 ) {
        if ($IS_WIN32) {
            $err = $merge ? '' : '>&STDERR';
            eval {
                $pid = open3( \*DUMMY, $out, $merge ? '' : $err, @command );
            };
            die "Could not execute (@command): $@" if $@;
            if ( $] >= 5.006 ) {

                # Kludge to avoid warning under 5.0.5
                eval 'binmode($out, ":crlf")';
            }
        }
        else {
            $err = $merge ? '' : IO::Handle->new;
            eval { $pid = open3( \*DUMMY, $out, $err, @command ); };
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

    if ( $] >= 5.008 ) {
        eval 'binmode($out, ":utf8")';
        eval 'binmode($err, ":utf8")' if ref $err;
    }

    my $self = bless {
        out  => $out,
        err  => $err,
        sel  => $sel,
        pid  => $pid,
        exit => undef,
    }, $class;

    if ( my $teardown = delete $args->{teardown} ) {
        $self->{teardown} = sub {
            $teardown->(@command);
        };
    }

    return $self;
}

##############################################################################

sub wait { shift->{wait} }
sub exit { shift->{exit} }

sub next_raw {
    my $self = shift;

    if ( my $out = $self->{out} ) {

        # If we have an IO::Select we need to poll it.
        if ( my $sel = $self->{sel} ) {
            my $err  = $self->{err};
            my $flip = 0;

            # Loops forever while we're reading from STDERR
            while ( my @ready = $sel->can_read ) {

                # Load balancing :)
                @ready = reverse @ready if $flip;
                $flip = !$flip;

                for my $fh (@ready) {
                    if ( defined( my $line = <$fh> ) ) {
                        if ( $fh == $err ) {
                            warn $line;
                        }
                        else {
                            chomp $line;
                            return $line;
                        }
                    }
                    else {
                        $sel->remove($fh);
                    }
                }
            }
        }
        else {

            # Only one handle: just a simple read
            if ( defined( my $line = <$out> ) ) {
                chomp $line;
                return $line;
            }
        }
    }

    # We only get here when the stream(s) is/are exhausted
    $self->_finish;

    return;
}

sub _finish {
    my $self = shift;

    my $status = $?;

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

    $self->{wait} = $status;
    $self->{exit} = $self->_wait2exit($status);

    if ( my $teardown = $self->{teardown} ) {
        $teardown->();
    }

    return $self;
}

1;
