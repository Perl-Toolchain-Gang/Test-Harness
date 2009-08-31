# subclass for testing TAP::Harness custom sources

package MyFileSourceDetector;

use strict;
use vars qw( @ISA $LAST_OBJ $CAN_HANDLE $MAKE_ITER $LAST_SOURCE );

use MyCustom;
use TAP::Parser::SourceDetector::File;

@ISA      = qw( TAP::Parser::SourceDetector::File MyCustom );
$LAST_OBJ = undef;
$CAN_HANDLE  = undef;
$MAKE_ITER   = undef;
$LAST_SOURCE = undef;

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = [@_];
    $LAST_OBJ = $self;
    return $self;
}

sub can_handle {
    my $class = shift;
    $class->SUPER::can_handle(@_);
    $CAN_HANDLE++;
    return $class;
}

sub make_iterator {
    my ($class, $source) = @_;
    my $iter = $class->SUPER::make_iterator( $source );
    $MAKE_ITER++;
    $LAST_SOURCE = $source;
    return $iter;
}

1;
