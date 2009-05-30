# subclass for testing customizing & subclassing

package MySourceDetector;

use strict;
use vars qw( @ISA );

use MyCustom;
use MySource;
use TAP::Parser::SourceFactory;
use TAP::Parser::SourceDetector;

@ISA = qw( TAP::Parser::SourceDetector MyCustom );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $main::INIT{ ref($self) }++;
    $self->{initialized} = 1;
    return $self;
}

sub can_handle {
    my ($class, $raw_source_ref, $meta, $config) = @_;
    if ($config->{accept_all}) {
	return 1;
    } elsif (my $accept = $config->{accept}) {
	return 0 unless $meta->{scalar};
	return 1 if $$raw_source_ref eq $accept;
    }
    return 0;
}

sub make_source {
    my ( $class, $raw_source_ref, $config ) = @_;
    my $source = MySource->new( $raw_source_ref, $config );
    $source->custom;
    $source->source( [$raw_source_ref] );
    return $source;
}

1;

