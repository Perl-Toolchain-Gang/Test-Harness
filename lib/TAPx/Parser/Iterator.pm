package TAPx::Parser::Iterator;

use strict;
use vars qw($VERSION);

=head1 NAME

TAPx::Parser::Iterator - Internal TAPx::Parser Iterator

=head1 VERSION

Version 0.51

=cut

$VERSION = '0.51';

=head1 SYNOPSIS

  use TAPx::Parser::Iterator;
  my $it = TAPx::Parser::Iterator->new(\*TEST);
  my $it = TAPx::Parser::Iterator->new(\@array);

  my $line = $it->next;
  if ( $it->is_first ) { ... }
  if ( $it->is_last ) { ... }

Originally ripped off from C<Test::Harness>.

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

This is a simple iterator wrapper for arrays and filehandles.

=head2 new()

Create an iterator.

=head2 next()

Iterate through it, of course.

=head2 next_raw()

Iterate raw input without applying any fixes for quirky input syntax.

=head2 is_first()

Returns true if on the first line.  Must be called I<after> C<next()>.

=head2 is_last()

Returns true if on or after the last line.  Must be called I<after> C<next()>.

=cut

sub new {
    my ( $proto, $thing ) = @_;

    my $ref = ref $thing;
    if ( $ref eq 'GLOB' || $ref eq 'IO::Handle' ) {

        # we may eventually allow a 'fast' switch which can read the entire
        # stream into an array.  This seems to speed things up by 10 to 12
        # per cent.  Should not be used with infinite streams.
        return TAPx::Parser::Iterator::FH->new($thing);
    }
    elsif ( $ref eq 'ARRAY' ) {
        return TAPx::Parser::Iterator::ARRAY->new($thing);
    }
    else {
        die "Can't iterate with a ", ref $thing;
    }
}

eval { require POSIX; &POSIX::WEXITSTATUS(0) };
if ($@) {
    *_wait2exit = sub { $_[1] >> 8 };
}
else {
    *_wait2exit = sub { POSIX::WEXITSTATUS( $_[1] ) }
}

package TAPx::Parser::Iterator::FH;

use vars qw($VERSION @ISA);
@ISA     = 'TAPx::Parser::Iterator';
$VERSION = '0.51';

sub new {
    my ( $class, $thing ) = @_;
    bless {
        fh       => $thing,
        next     => undef,
        exit     => undef,
        is_first => 0,
        is_last  => 0,
    }, $class;
}

##############################################################################

=head3 C<pid>

  my $pid = $source->pid;
  $source->pid($pid);

Getter/Setter for the pid of the process the filehandle reads from.  Only
makes sense when a filehandle is being used for the iterator.

=cut

sub pid {
    my $self = shift;
    return $self->{pid} unless @_;
    $self->{pid} = shift;
    return $self;
}

sub wait     { $_[0]->{wait} }
sub exit     { $_[0]->{exit} }
sub is_first { $_[0]->{is_first} }
sub is_last  { $_[0]->{is_last} }

sub next_raw {
    my $self = shift;
    my $fh   = $self->{fh};

    my $line;
    if ( defined( $line = $self->{next} ) ) {
        if ( defined( my $next = <$fh> ) ) {
            chomp( $self->{next} = $next );
            $self->{is_first} = 0;
        }
        else {
            $self->_finish;
        }
    }
    else {
        $self->{is_first} = 1 unless $self->{is_last};
        local $^W;    # Don't want to chomp undef values
        chomp( $line = <$fh> );
        unless ( defined $line ) {
            $self->_finish;
        }
        else {
            chomp( $self->{next} = <$fh> );
        }
    }

    return $line;
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

    close $self->{fh};

    $self->{is_first} = 0;   # need to reset it here in case we have no output
    $self->{is_last}  = 1;
    $self->{next} = undef;
    $self->{wait} = $status;
    $self->{exit} = $self->_wait2exit($status);
    return $self;
}

package TAPx::Parser::Iterator::ARRAY;

use vars qw($VERSION @ISA);
@ISA     = 'TAPx::Parser::Iterator';
$VERSION = '0.51';

sub new {
    my ( $class, $thing ) = @_;
    chomp @$thing;
    bless {
        idx   => 0,
        array => $thing,
        exit  => undef,
    }, $class;
}

sub wait     { shift->exit }
sub exit     { shift->is_last ? 0 : () }
sub is_first { 1 == $_[0]->{idx} }
sub is_last  { @{ $_[0]->{array} } <= $_[0]->{idx} }

sub next {
    my $self = shift;
    return $self->{array}->[ $self->{idx}++ ];
}

sub next_raw { shift->next }

1;
