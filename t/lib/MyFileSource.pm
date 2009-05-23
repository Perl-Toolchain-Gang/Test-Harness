# subclass for testing TAP::Harness custom sources

package MyFileSource;

use strict;
use vars qw( @ISA $LAST_OBJ );

use MyCustom;
use TAP::Parser::Source::Executable;

@ISA = qw( TAP::Parser::Source::File MyCustom );
$LAST_OBJ = undef;

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = [ @_ ];
    $LAST_OBJ = $self;
    return $self;
}

sub source {
    my $self = shift;
    return $self->SUPER::source(@_);
}

sub get_stream {
    my $self   = shift;
    my $stream = $self->SUPER::get_stream(@_);

    # re-bless it:
    bless $stream, 'MyIterator';
}

1;
