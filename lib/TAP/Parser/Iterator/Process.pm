package TAP::Parser::Iterator::Process;

use strict;
use TAP::Parser::Iterator;
use vars qw($VERSION @ISA);
@ISA = 'TAP::Parser::Iterator';

use IPC::Open3;
use IO::Select;
use IO::Handle;

use constant IS_WIN32 => ( $^O =~ /^(MS)?Win32$/ );
use constant IS_MACOS => ( $^O eq 'MacOS' );
use constant IS_VMS   => ( $^O eq 'VMS' );

=head1 NAME

TAP::Parser::Iterator::Process - Internal TAP::Parser Iterator

=head1 VERSION

Version 0.52

=cut

$VERSION = '0.52';

=head1 SYNOPSIS

  use TAP::Parser::Iterator;
  my $it = TAP::Parser::Iterator::Process->new(@args);

  my $line = $it->next;

Originally ripped off from C<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for processes.

=head2 new()

Create an iterator.

=head2 next()

Iterate through it, of course.

=head2 next_raw()

Iterate raw input without applying any fixes for quirky input syntax.

=head2 wait()

Get the wait status for this iterator's process.

=head2 exit()

Get the exit status for this iterator's process.

=cut

eval { require POSIX; &POSIX::WEXITSTATUS(0) };
if ($@) {
    *_wait2exit = sub { $_[1] >> 8 };
}
else {
    *_wait2exit = sub { POSIX::WEXITSTATUS( $_[1] ) }
}

sub _open_process {
    my $self    = shift;
    my $merged  = shift;
    my @command = @_;

    my $out = IO::Handle->new;
    my $pid;

    my $err = $merged ? undef : '>&STDERR';

    eval { $pid = open3( undef, $out, $err, @command ); };

    if ($@) {

        # TODO: Need to do something better with the error info here.
        # $self->exit( $? >> 8 );
        # $self->error("Could not execute (@command): $!");
        die "Could not execute (@command): $@";
    }

    if (IS_WIN32) {

        # open3 defaults to raw mode, need this for Windows. Maybe
        # other platforms too?
        # TODO: What was the first perl version that supports this?
        binmode $out, ':crlf';
    }

    return ( $out, $pid );
}

sub new {
    my $class = shift;
    my $args  = shift;

    my @command = @{ delete $args->{command} }
      or die "Must supply a command to execute";
    my $merge = delete $args->{merge};

    my $self = bless { exit => undef }, $class;

    my ($out, $pid) = $self->_open_process($merge, @command);

    $self->{out} = $out;
    $self->{pid} = $pid;

    return $self;
}

##############################################################################

sub wait { $_[0]->{wait} }
sub exit { $_[0]->{exit} }

sub next_raw {
    my $self = shift;

    # my $out  = $self->{out};
    # my $err  = $self->{err};

    my $fh = $self->{out};

    if ( defined( my $line = <$fh> ) ) {
        chomp $line;
        return $line;
    }
    else {
        $self->_finish;
        return;
    }

    # my $sel = IO::Select->new( $out, $err );
    #
    # if ( my @ready = $sel->can_read ) {
    #     for my $fh (@ready) {
    #         if ( eof($fh) ) {
    #             $sel->remove($fh);
    #             next;
    #         }
    #         if ( defined( my $line = <$fh> ) ) {
    #             chomp $line;
    #             return $line;
    #         }
    #         else {
    #             die "Oops: unexpected eof";
    #         }
    #     }
    # }
    #
    # $self->_finish;
    return;
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

    my $status = $?;

    # If we have a subprocess we need to wait for it to terminate
    if ( defined $self->{pid} ) {
        if ( $self->{pid} == waitpid( $self->{pid}, 0 ) ) {
            $status = $?;
        }
    }

    close $self->{out};

    #    close $self->{err};

    $self->{next} = undef;
    $self->{wait} = $status;
    $self->{exit} = $self->_wait2exit($status);
    return $self;
}

1;
