# subclass for testing customizing & subclassing

package MySourceDetector;

use strict;
use vars '@ISA';

use MyCustom;
use TAP::Parser::SourceFactory;

#use TAP::Parser::SourceDetector::Executable;
use TAP::Parser::SourceDetector;

@ISA = qw( TAP::Parser::SourceDetector MyCustom );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

sub can_handle {
    my ( $class, $src ) = @_;
    my $meta   = $src->meta;
    my $config = $src->config_for( $class );

    if ( $config->{accept_all} ) {
        return 1;
    }
    elsif ( my $accept = $config->{accept} ) {
        return 0 unless $meta->{is_scalar};
        return 1 if ${ $src->raw } eq $accept;
    }
    return 0;
}

sub make_source {
    my ( $class, $src ) = @_;
    my $meta   = $src->meta;
    my $config = $src->config_for( $class );
    my $source = $class->new;
    $source->config( $config )->source([ $src->raw ])->custom;
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
