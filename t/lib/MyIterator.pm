# subclass for testing customizing & subclassing

package MyIterator;

use strict;
use vars '@ISA';

use MyCustom;
use TAP::Parser::Iterator;

@ISA = qw( TAP::Parser::Iterator MyCustom );

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ref($self)}++;
    $self->{initialized} = 1;
    return $self;
}

1;
