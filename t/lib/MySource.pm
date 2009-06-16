# subclass for testing customizing & subclassing

package MySource;

use strict;
use vars '@ISA';

use MyCustom;
use TAP::Parser::SourceFactory;

#use TAP::Parser::Source::Executable;
use TAP::Parser::Source;

@ISA = qw( TAP::Parser::Source MyCustom );

TAP::Parser::SourceFactory->register_source(__PACKAGE__);

sub can_handle {
    my ( $class, $raw_source_ref, $meta, $config ) = @_;
    if ( $config->{accept_all} ) {
        return 1;
    }
    elsif ( my $accept = $config->{accept} ) {
        return 0 unless $meta->{scalar};
        return 1 if $$raw_source_ref eq $accept;
    }
    return 0;
}

sub make_source {
    my ( $class, $args ) = @_;
    my $raw_source_ref = $args->{raw_source_ref};
    my $source         = $class->new;
    $source->config( $args->{config} )->source( [$raw_source_ref] )->custom;
    return $source;
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

sub get_stream {
    my ( $self, $factory ) = @_;
    my $iter = $factory->make_iterator( $self->raw_source );

    #    my $stream = $self->SUPER::get_stream(@_);

    # re-bless it:
    bless $iter, 'MyIterator';
}

1;
