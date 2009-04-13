# subclass for testing customizing & subclassing

package MySourceDetector;

use strict;
use vars '@ISA';

use MyCustom;
use MySource;
use TAP::Parser::SourceFactory;
use TAP::Parser::SourceDetector;

@ISA = qw( TAP::Parser::SourceDetector MyCustom );

TAP::Parser::SourceFactory->register_detector( __PACKAGE__ );

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = 1;
    return $self;
}

sub can_handle {
    my ($class, $raw_source_ref) = @_;
    return 0   unless defined $$raw_source_ref;
    return 0   if $$raw_source_ref =~ /\n/;
    return 1   if $$raw_source_ref eq 'known-source';
    return 0.5 if $$raw_source_ref eq 'half-known-source';
    return 0;
}

sub make_source {
    my ($class, $raw_source_ref) = @_;
    my $source = MySource->new;
    $source->source([ $raw_source_ref ]);
    return $source;
}

1;

