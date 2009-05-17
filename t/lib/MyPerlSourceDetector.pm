# subclass for testing customizing & subclassing

package MySourcePerlDetector;

use strict;
use vars '@ISA';

use MyCustom;
use MyPerlSource;
use TAP::Parser::SourceFactory;
use TAP::Parser::SourceDetector::Perl;

@ISA = qw( TAP::Parser::SourceDetector::Perl MyCustom );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

use constant source_class => 'MyPerlSource';

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = 1;
    return $self;
}

sub can_handle {
    my $class = shift;
    my $vote  = $class->SUPER::can_handle(@_);
    $vote    += 0.1 if $vote > 0; # steal the Perl detector's vote
    return $vote;
}

sub make_source {
    my $class  = shift;
    my $source = $class->SUPER::make_source(@_);
    return $source->custom;
}

1;

