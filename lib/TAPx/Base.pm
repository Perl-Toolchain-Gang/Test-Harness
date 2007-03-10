package TAPx::Base;

use strict;
use vars qw($VERSION);

=head1 NAME

TAPx::Base - Base class that provides common functionality to L<TAPx::Parser> and L<TAPx::Harness>

=head1 VERSION

Version 0.51

=cut

$VERSION = '0.51';

=head1 SYNOPSIS

    package TAPx::Whatever;

    use TAPx::Base;
    
    use vars qw($VERSION @ISA);
    @ISA = qw(TAPx::Base);

    # ... later ...
    
    my $thing = TAPx::Whatever->new();
    
    $thing->callback( event => sub {
        # do something interesting
    } );

=head1 DESCRIPTION

C<TAPx::Base> provides callback management.

=head1 METHODS

=head2 Class methods

=head3 C<new>

=cut

sub new {
    my ( $class, $arg_for ) = @_;

    my $self = bless {}, $class;
    return $self->_initialize($arg_for);
}

sub _initialize {
    my ( $self, $arg_for, $ok_callback ) = @_;

    my %ok_map = map { $_ => 1 } @$ok_callback;

    $self->{ok_callbacks} = \%ok_map;

    if ( exists $arg_for->{callbacks} ) {
        while ( my ( $event, $callback ) = each %{ $arg_for->{callbacks} } ) {
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

    $self->{code_for}{$event} = $callback;
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
    return $cb->(@_);
}

sub _croak {
    my ( $self, $message ) = @_;
    require Carp;
    Carp::croak($message);
}

1;
