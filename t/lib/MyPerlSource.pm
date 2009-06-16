# subclass for testing customizing & subclassing

package MyPerlSource;

use strict;
use vars '@ISA';

use MyCustom;
use TAP::Parser::Source::Perl;
use TAP::Parser::SourceFactory;

@ISA = qw( TAP::Parser::Source::Perl MyCustom );

TAP::Parser::SourceFactory->register_source(__PACKAGE__);

sub can_handle {
    my $class = shift;
    my $vote  = $class->SUPER::can_handle(@_);
    $vote += 0.1 if $vote > 0;    # steal the Perl detector's vote
    return $vote;
}

sub make_source {
    my $class  = shift;
    my $source = $class->SUPER::make_source(@_);
    return $source->custom;
}

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = 1;
    return $self;
}

sub source {
    my $self = shift;
    return $self->SUPER::source(@_);
}

1;

