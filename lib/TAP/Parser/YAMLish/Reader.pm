package TAP::Parser::YAMLish::Reader;

use strict;
use warnings;

use vars qw{$VERSION};

$VERSION = '0.52';

# Printable characters for escapes
my %UNESCAPES = (
    z => "\x00", a => "\x07", t    => "\x09",
    n => "\x0a", v => "\x0b", f    => "\x0c",
    r => "\x0d", e => "\x1b", '\\' => '\\',
);

my $QQ_STRING    = qr{ " (?:\\. | [^"])* " }x;
my $HASH_LINE    = qr{ ^ ($QQ_STRING|\S+) \s* : (?: \s+ (.+?) \s* )? $ }x;
my $IS_HASH_KEY  = qr{ ^ [\w\'\"] }x;
my $IS_END_YAML  = qr{ ^ [.][.][.] \s* $ }x;
my $IS_QQ_STRING = qr{ ^ $QQ_STRING $ }x;

# Create an empty TAP::Parser::YAMLish::Reader object
sub new {
    my $class = shift;
    bless {}, $class;
}

sub read {
    my $self = shift;
    my $obj  = shift;

    # Extra lines to prepend to the YAML stream. Crazy interface but it
    # makes it easier for us to jump in here from the T::P::Grammar.
    # This interface may change.
    my @extra = @_;

    die "Must have something to read from"
      unless defined $obj;

    # This interface is pretty specific to TAP iterators - because
    # that's all we currently need - but that dependency is isolated
    # here. After this point all we have is a closure that we call to
    # get the next line of input sans newline.
    unless ( 'CODE' eq ref $obj ) {
        my $next = eval { $obj->can('next') };
        die "Don't know how to get input from $obj"
          unless $next;
        my $target = $obj;
        $obj = sub { $target->$next(); };
    }

    # Modify the iterator to include any extra lines we've been passed.
    if (@extra) {
        my $reader = $obj;
        $obj = sub {
            return shift @extra if @extra;
            return $reader->();
          }
    }

    $self->{reader}  = $obj;
    $self->{capture} = [];

    # Prime the reader
    $self->_next;

    my $doc = $self->_read;

    # The terminator is mandatory otherwise we'd consume a line from the
    # iterator that doesn't belong to us. If we want to remove this
    # restriction we'll have to implement look-ahead in the iterators.
    # Which might not be a bad idea.
    my $dots = $self->_peek;
    die "Missing '...' at end of YAMLish"
      unless $dots =~ $IS_END_YAML;

    delete $self->{reader};
    delete $self->{next};

    return $doc;
}

sub get_raw {
    my $self = shift;

    if ( defined( my $capture = $self->{capture} ) ) {
        return join( "\n", @$capture ) . "\n";
    }

    return '';
}

sub _peek {
    my $self = shift;
    return $self->{next} unless wantarray;
    my $line = $self->{next};
    $line =~ /^ (\s*) (.*) $ /x;
    return ( $2, length $1 );
}

sub _next {
    my $self = shift;
    die "_next called with no reader"
      unless $self->{reader};
    my $line = $self->{reader}->();
    $self->{next} = $line;
    push @{ $self->{capture} }, $line;
}

sub _read {
    my $self = shift;

    my $line = $self->_peek;

    # Do we have a document header?
    if ( $line =~ /^ --- (?: \s* (.+?) \s* )? $/x ) {
        $self->_next;

        return $self->_read_scalar($1) if defined $1;    # Inline?

        my ( $next, $indent ) = $self->_peek;

        if ( $next =~ /^ - /x ) {
            return $self->_read_array($indent);
        }
        elsif ( $next =~ $IS_HASH_KEY ) {
            return $self->_read_hash( $next, $indent );
        }
        elsif ( $next =~ $IS_END_YAML ) {
            die "Premature end of YAMLish";
        }
        else {
            die "Unsupported YAMLish syntax: '$next'";
        }
    }
    else {
        die "YAMLish document header not found";
    }
}

# Parse a double quoted string
sub _read_qq {
    my $self = shift;
    my $str  = shift;

    # For convenient handling of hash keys we just return our argument
    # if it doesn't look like a quoted string.
    unless ( $str =~ s/^ " (.*?) " $/$1/x ) {
        return $str;
    }

    $str =~ s/\\"/"/gx;
    $str =~ s/ \\ ( [tartan\\favez] | x([0-9a-fA-F]{2}) ) 
                 / (length($1) > 1) ? pack("H2", $2) : $UNESCAPES{$1} /gex;
    return $str;
}

# Parse a scalar string to the actual scalar
sub _read_scalar {
    my $self   = shift;
    my $string = shift;

    return undef if $string eq '~';

    if ( $string =~ /^ ' (.*) ' $/x ) {
        ( my $rv = $1 ) =~ s/''/'/g;
        return $rv;
    }

    if ( $string =~ $IS_QQ_STRING ) {
        return $self->_read_qq($string);
    }

    if ( $string =~ /^['"]/ ) {

        # A quote with folding... we don't support that
        die __PACKAGE__ . " does not support multi-line quoted scalars";
    }

    # Regular unquoted string
    return $string unless $string eq '>' or $string eq '|';

    my ( $line, $indent ) = $self->_peek;
    die "Multi-line scalar content missing" unless defined $line;

    my @multiline = ($line);

    while (1) {
        $self->_next;
        my ( $next, $ind ) = $self->_peek;
        last if $ind < $indent;
        push @multiline, $next;
    }

    return join( ( $string eq '>' ? ' ' : "\n" ), @multiline ) . "\n";
}

sub _read_nested {
    my $self = shift;

    my ( $line, $indent ) = $self->_peek;

    if ( $line =~ /^ -/x ) {
        return $self->_read_array($indent);
    }
    elsif ( $line =~ $IS_HASH_KEY ) {
        return $self->_read_hash( $line, $indent );
    }
    else {
        die "Unsupported YAMLish syntax: '$line'";
    }
}

# Parse an array
sub _read_array {
    my ( $self, $limit ) = @_;

    my $ar = [];

    while (1) {
        my ( $line, $indent ) = $self->_peek;
        last if $indent < $limit || !defined $line || $line =~ $IS_END_YAML;

        if ( $indent > $limit ) {
            die "Array line over-indented";
        }

        if ( $line =~ /^ (- \s+) \S+ \s* : (?: \s+ | $ ) /x ) {
            $indent += length $1;
            $line =~ s/-\s+//;
            push @$ar, $self->_read_hash( $line, $indent );
        }
        elsif ( $line =~ /^ - \s* (.+?) \s* $/x ) {
            die "Unexpected start of YAMLish" if $line =~ /^---/;
            $self->_next;
            push @$ar, $self->_read_scalar($1);
        }
        elsif ( $line =~ /^ - \s* $/x ) {
            $self->_next;
            push @$ar, $self->_read_nested;
        }
        elsif ( $line =~ $IS_HASH_KEY ) {
            $self->_next;
            push @$ar, $self->_read_hash( $line, $indent, );
        }
        else {
            die "Unsupported YAMLish syntax: '$line'";
        }
    }

    return $ar;
}

sub _read_hash {
    my ( $self, $line, $limit ) = @_;

    my $indent;
    my $hash = {};

    while (1) {
        die "Badly formed hash line: '$line'"
          unless $line =~ $HASH_LINE;

        my ( $key, $value ) = ( $self->_read_qq($1), $2 );
        $self->_next;

        if ( defined $value ) {
            $hash->{$key} = $self->_read_scalar($value);
        }
        else {
            $hash->{$key} = $self->_read_nested;
        }

        ( $line, $indent ) = $self->_peek;
        last if $indent < $limit || !defined $line || $line =~ $IS_END_YAML;
    }

    return $hash;
}

1;

__END__

=pod

=head1 NAME

TAP::Parser::YAMLish::Reader - Read YAMLish data from iterator

=head1 VERSION

Version 0.52

=head1 SYNOPSIS

=head1 DESCRIPTION

Note that parts of this code were derived from L<YAML::Tiny> with the
permission of Adam Kennedy.

=head1 METHODS

=over

=item C<< new >>

The constructor C<new> creates and returns an empty C<TAP::Parser::YAMLish::Reader> object.

=item C<< read( $stream ) >>

Read YAMLish from a TAP::Parser::Iterator and return the data structure it represents.

=item C<< get_raw >>

Return the raw YAMLish source from the most recent C<read>.

=back

=head1 AUTHOR

Andy Armstrong, <andy@hexten.net>

Adam Kennedy wrote L<YAML::Tiny> which provided the template and many of
the YAML matching regular expressions for this module.

=head1 SEE ALSO

L<YAML::Tiny>, L<YAML>, L<YAML::Syck>, L<Config::Tiny>, L<CSS::Tiny>,
L<http://use.perl.org/~Alias/journal/29427>

=head1 COPYRIGHT

Copyright 2007 Andy Armstrong.

Portions copyright 2006-2007 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

