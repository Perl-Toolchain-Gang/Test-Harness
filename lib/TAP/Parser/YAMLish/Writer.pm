package TAP::Parser::YAMLish::Writer;

use strict;
use warnings;

use vars qw{$VERSION};

$VERSION = '0.52';

my $ESCAPE_CHAR = qr{ [ \x00-\x1f \" ] }x;

my @UNPRINTABLE = qw(
  z    x01  x02  x03  x04  x05  x06  a
  x08  t    n    v    f    r    x0e  x0f
  x10  x11  x12  x13  x14  x15  x16  x17
  x18  x19  x1a  e    x1c  x1d  x1e  x1f
);

# Create an empty TAP::Parser::YAMLish::Writer object
sub new {
    my $class = shift;
    bless {}, $class;
}

sub write {
    my $self = shift;
    my $obj  = shift;
    my $out  = shift || \*STDOUT;

    die "Need something to write"
      unless defined $obj;

    die "Need a reference to something I can write to"
      unless ref $out;

    $self->{writer} = $self->_make_writer($out);

    $self->_write_obj( '---', $obj );
    $self->_put('...');

    delete $self->{writer};
}

sub _make_writer {
    my $self = shift;
    my $out  = shift;

    my $ref = ref $out;

    if ( 'CODE' eq $ref ) {
        return $out;
    }

    die "Can't write to $out";
}

sub _put {
    my $self = shift;
    $self->{writer}->( join '', @_ );
}

sub _enc_scalar {
    my $self = shift;
    my $val  = shift;

    return '~' unless defined $val;

    if ( $val =~ /$ESCAPE_CHAR/ ) {
        $val =~ s/\\/\\\\/g;
        $val =~ s/"/\\"/g;

        #$val =~ s/\n/\\n/g;
        $val =~ s/ ( [\x00-\x1f] ) / '\\' . $UNPRINTABLE[ ord($1) ] /gex;
        return qq{"$val"};
    }

    if ( length($val) == 0 or $val =~ /\s/ ) {
        $val =~ s/'/''/;
        return "'$val'";
    }

    return $val;
}

sub _write_obj {
    my $self   = shift;
    my $prefix = shift;
    my $obj    = shift;
    my $indent = shift || 0;

    if ( my $ref = ref $obj ) {
        my $pad = '  ' x $indent;
        $self->_put($prefix);
        if ( 'HASH' eq $ref ) {
            for my $key ( sort keys %$obj ) {
                my $value = $obj->{$key};
                $self->_write_obj(
                    $pad . $self->_enc_scalar($key) . ':',
                    $value, $indent + 1
                );
            }
        }
        elsif ( 'ARRAY' eq $ref ) {
            for my $value (@$obj) {
                $self->_write_obj( $pad . '-', $value, $indent + 1 );
            }
        }
        else {
            die "Don't know how to enocde $ref";
        }
    }
    else {
        $self->_put( $prefix, ' ', $self->_enc_scalar($obj) );
    }
}

1;

__END__

=pod

=head1 NAME

TAP::Parser::YAMLish::Writer - Write YAMLish data

=head1 VERSION

Version 0.52

=head1 SYNOPSIS

=head1 DESCRIPTION

Encodes a scalar, hash reference or array reference as YAMLish.

=head1 METHODS

=over

=item C<< new >>

The constructor C<new> creates and returns an empty C<TAP::Parser::YAMLish::Writer> object.

=item C<< write( $obj, $stream ) >>

Encode a scalar, hash reference or array reference as YAMLish.
The second argument is a closure that will be called for each
line of output. If omitted output goes to STDOUT.

    my $writer = sub {
        my $line = shift;
        print SOMEFILE "$line\n";
    };
    
    my $data = {
        one => 1,
        two => 2,
        three => [ 1, 2, 3 ],
    };
    
    my $yw = TAP::Parser::YAMLish::Writer->new;
    $yw->write( $data, $writer );

=back

=head1 AUTHOR

Andy Armstrong, <andy@hexten.net>

=head1 SEE ALSO

L<YAML::Tiny>, L<YAML>, L<YAML::Syck>, L<Config::Tiny>, L<CSS::Tiny>,
L<http://use.perl.org/~Alias/journal/29427>

=head1 COPYRIGHT

Copyright 2007 Andy Armstrong.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

