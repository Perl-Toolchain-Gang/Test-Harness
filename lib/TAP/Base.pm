package TAP::Base;

use strict;
use warnings;

use base 'TAP::Object';

=head1 NAME

TAP::Base - Base class that provides common functionality to L<TAP::Parser>
and L<TAP::Harness>

=head1 VERSION

Version 3.52

=cut

our $VERSION = '3.52';

use Time::HiRes qw(time);

=head1 SYNOPSIS

    package TAP::Whatever;

    use base 'TAP::Base';

    # ... later ...
    
    my $thing = TAP::Whatever->new();
    
    $thing->callback( event => sub {
        # do something interesting
    } );

=head1 DESCRIPTION

C<TAP::Base> provides callback management.

=head1 METHODS

=head2 Class Methods

=cut

sub _initialize {
    my ( $self, $arg_for, $ok_callback ) = @_;

    my %ok_map = map { $_ => 1 } @$ok_callback;

    $self->{ok_callbacks} = \%ok_map;

    if ( my $cb = delete $arg_for->{callbacks} ) {
        while ( my ( $event, $callback ) = each %$cb ) {
            $self->callback( $event, $callback );
        }
    }

    return $self;
}

=head3 C<callback>

Install a callback for a named event.

=cut

sub callback {
    my ( $self, $event, $callback ) = @_;

    my %ok_map = %{ $self->{ok_callbacks} };

    $self->_croak('No callbacks may be installed')
      unless %ok_map;

    $self->_croak( "Callback $event is not supported. Valid callbacks are "
          . join( ', ', sort keys %ok_map ) )
      unless exists $ok_map{$event};

    push @{ $self->{code_for}{$event} }, $callback;

    return;
}

sub _has_callbacks {
    my $self = shift;
    return keys %{ $self->{code_for} } != 0;
}

sub _callback_for {
    my ( $self, $event ) = @_;
    return $self->{code_for}{$event};
}

sub _make_callback {
    my $self  = shift;
    my $event = shift;

    my $cb = $self->_callback_for($event);
    return unless defined $cb;
    return map { $_->(@_) } @$cb;
}

=head3 C<get_time>

Return the current time.

=cut

sub get_time { return time() }

# kept for backwards compatability
sub time_is_hires { return 1 }

=head3 C<get_times>

Return array reference of the four-element list of CPU seconds,
as with L<perlfunc/times>.

=cut

sub get_times { return [ times() ] }

1;
