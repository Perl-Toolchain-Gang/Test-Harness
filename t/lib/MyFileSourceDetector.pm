# subclass for testing TAP::Harness custom sources

package MyFileSourceDetector;

use strict;
use vars qw( @ISA $LAST_OBJ );

use MyCustom;
use TAP::Parser::SourceDetector::File;

@ISA      = qw( TAP::Parser::SourceDetector::File MyCustom );
$LAST_OBJ = undef;

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = [@_];
    $LAST_OBJ = $self;
    return $self;
}

1;
