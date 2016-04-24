package TAP::Parser::Iterator::Process;

use strict;
use warnings;

use Config;

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
    my $class;
    if(!IS_WIN32 || (eval { require TAP::Parser::Iterator::Process::Windows }, $@)) {
            require TAP::Parser::Iterator::Process::Unix;
            $class = 'TAP::Parser::Iterator::Process::Unix';
    } else {
        $class = 'TAP::Parser::Iterator::Process::Windows';
    }
    sub new {
        shift;
        return $class->SUPER::new(@_);
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

=head3 C<handle_unicode>

Upgrade the input stream to handle UTF8.

=cut

##############################################################################

sub wait { shift->{wait} }
sub exit { shift->{exit} }

sub next_raw {
    my $self = shift;
    return ( $self->{_next} ||= $self->_next )->();
}

=head3 C<get_select_handles>

Return a list of filehandles that may be used upstream in a select()
call to signal that this Iterator is ready. Iterators that are not
handle based should return an empty list.

=cut

1;

=head1 ATTRIBUTION

Originally ripped off from L<Test::Harness>.

=head1 SEE ALSO

L<TAP::Object>,
L<TAP::Parser>,
L<TAP::Parser::Iterator>,

=cut

