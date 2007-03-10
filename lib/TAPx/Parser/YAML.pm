package TAP::Parser::YAML;

use 5.005;
use strict;

use vars qw{$VERSION @ISA @EXPORT_OK $errstr};

BEGIN {
    $VERSION = '0.51';
    $errstr  = '';

    require Exporter;
    @ISA       = qw{ Exporter  };
    @EXPORT_OK = qw{ Load Dump };
}

# Create the main error hash
my %ERROR = (
    YAML_PARSE_ERR_NO_FINAL_NEWLINE =>
      "Stream does not end with newline character",

);

my %NO = (
    '%' => 'TAP::Parser::YAML does not support directives',
    '&' => 'TAP::Parser::YAML does not support anchors',
    '*' => 'TAP::Parser::YAML does not support aliases',
    '?' => 'TAP::Parser::YAML does not support explicit mapping keys',
    ':' => 'TAP::Parser::YAML does not support explicit mapping values',
    '!' => 'TAP::Parser::YAML does not support explicit tags',
);

my $ESCAPE_CHAR = '[\\x00-\\x08\\x0b-\\x0d\\x0e-\\x1f\"\n]';

# Escapes for unprintable characters
my @UNPRINTABLE = qw(z    x01  x02  x03  x04  x05  x06  a
  x08  t    n    v    f    r    x0e  x0f
  x10  x11  x12  x13  x14  x15  x16  x17
  x18  x19  x1a  e    x1c  x1d  x1e  x1f
);

# Printable characters for escapes
my %UNESCAPES = (
    z => "\x00", a => "\x07", t    => "\x09",
    n => "\x0a", v => "\x0b", f    => "\x0c",
    r => "\x0d", e => "\x1b", '\\' => '\\',
);

# Create an empty TAP::Parser::YAML object
sub new {
    my $class = shift;
    bless [@_], $class;
}

# Create an object from a file
sub read {
    my $class = ref $_[0] ? ref shift: shift;

    # Check the file
    my $file = shift
      or return $class->_error('You did not specify a file name');
    return $class->_error("File '$file' does not exist") unless -e $file;
    return $class->_error("'$file' is a directory, not a file") unless -f _;
    return $class->_error("Insufficient permissions to read '$file'")
      unless -r _;

    # Slurp in the file
    local $/ = undef;
    open CFG, $file
      or return $class->_error("Failed to open file '$file': $!");
    my $contents = <CFG>;
    close CFG;

    $class->read_string($contents);
}

# Create an object from a string
sub read_string {
    my $class = ref $_[0] ? ref shift: shift;
    my $self = bless [], $class;

    # Handle special cases
    return undef unless defined $_[0];
    return $self unless length $_[0];
    unless ( $_[0] =~ /[\012\015]+$/ ) {
        return $class->_error('YAML_PARSE_ERR_NO_FINAL_NEWLINE');
    }

    # Split the file into lines
    my @lines = grep { !/^\s*(?:\#.+)?$/ }
      split /(?:\015{1,2}\012|\015|\012)/, shift;

    # A nibbling parser
    while (@lines) {

        # Do we have a document header?
        if ( $lines[0] =~ /^---(?:\s*(.+)\s*)?$/ ) {

            # Handle scalar documents
            shift @lines;
            if ( defined $1 ) {
                push @$self, $self->_read_scalar( "$1", [undef], \@lines );
                next;
            }
        }

        if ( !@lines or $lines[0] =~ /^---(?:\s*(.+)\s*)?$/ ) {

            # A naked document
            push @$self, undef;

        }
        elsif ( $lines[0] =~ /^\s*\-/ ) {

            # An array at the root
            my $document = [];
            push @$self, $document;
            $self->_read_array( $document, [0], \@lines );

        }
        elsif ( $lines[0] =~ /^(\s*)\w/ ) {

            # A hash at the root
            my $document = {};
            push @$self, $document;
            $self->_read_hash( $document, [ length($1) ], \@lines );

        }
        else {
            die "CODE INCOMPLETE (are you sure this is a YAML file?)";
        }
    }

    $self;
}

sub _check_support {

    # Check if we support the next char
    my $errstr = $NO{ substr( $_[1], 0, 1 ) };
    Carp::croak($errstr) if $errstr;
}

# Deparse a scalar string to the actual scalar
sub _read_scalar {
    my ( $self, $string, $indent, $lines ) = @_;
    return undef if $string eq '~';
    if ( $string =~ /^'(.*?)'$/ ) {
        return '' unless defined $1;
        my $rv = $1;
        $rv =~ s/''/'/g;
        return $rv;
    }
    if ( $string =~ /^"((?:\\.|[^"])*)"$/ ) {
        my $str = $1;
        $str =~ s/\\"/"/g;
        $str
          =~ s/\\([never\\fartz]|x([0-9a-fA-F]{2}))/(length($1)>1)?pack("H2",$2):$UNESCAPES{$1}/gex;
        return $str;
    }
    if ( $string =~ /^['"]/ ) {

        # A quote with folding... we don't support that
        die "TAP::Parser::YAML does not support multi-line quoted scalars";
    }
    unless ( $string eq '>' or $string eq '|' ) {

        # Regular unquoted string
        return $string;
    }

    # Error
    die "Multi-line scalar content missing" unless @$lines;

    # Check the indent depth
    $lines->[0] =~ /^(\s*)/;
    $indent->[-1] = length("$1");
    if ( defined $indent->[-2] and $indent->[-1] <= $indent->[-2] ) {
        die "Illegal line indenting";
    }

    # Pull the lines
    my @multiline = ();
    while (@$lines) {
        $lines->[0] =~ /^(\s*)/;
        last unless length($1) >= $indent->[-1];
        push @multiline, substr( shift(@$lines), length($1) );
    }

    join( ( $string eq '>' ? ' ' : "\n" ), @multiline ) . "\n";
}

# Parse an array
sub _read_array {
    my ( $self, $array, $indent, $lines ) = @_;

    while (@$lines) {
        $lines->[0] =~ /^(\s*)/;
        if ( length($1) < $indent->[-1] ) {
            return 1;
        }
        elsif ( length($1) > $indent->[-1] ) {
            die "Hash line over-indented";
        }

        if ( $lines->[0] =~ /^(\s*\-\s+)\S+\s*:(?:\s+|$)/ ) {

            # Inline nested hash
            my $indent2 = length("$1");
            $lines->[0] =~ s/-/ /;
            push @$array, {};
            $self->_read_hash( $array->[-1], [ @$indent, $indent2 ], $lines );

        }
        elsif ( $lines->[0] =~ /^\s*\-(\s*)(.+?)\s*$/ ) {

            # Array entry with a value
            shift @$lines;
            push @$array,
              $self->_read_scalar( "$2", [ @$indent, undef ], $lines );

        }
        elsif ( $lines->[0] =~ /^\s*\-\s*$/ ) {
            shift @$lines;
            if ( $lines->[0] =~ /^(\s*)\-/ ) {
                my $indent2 = length("$1");
                if ( $indent->[-1] == $indent2 ) {

                    # Null array entry
                    push @$array, undef;
                }
                else {

                    # Naked indenter
                    push @$array, [];
                    $self->_read_array(
                        $array->[-1], [ @$indent, $indent2 ],
                        $lines
                    );
                }

            }
            elsif ( $lines->[0] =~ /^(\s*)\w/ ) {
                push @$array, {};
                $self->_read_hash(
                    $array->[-1], [ @$indent, length("$1") ],
                    $lines
                );

            }
            else {
                die "CODE INCOMPLETE";
            }

        }
        else {
            die "CODE INCOMPLETE";
        }
    }

    return 1;
}

# Parse an array
sub _read_hash {
    my ( $self, $hash, $indent, $lines ) = @_;

    while (@$lines) {
        $lines->[0] =~ /^(\s*)/;
        if ( length($1) < $indent->[-1] ) {
            return 1;
        }
        elsif ( length($1) > $indent->[-1] ) {
            die "Hash line over-indented";
        }

        # Get the key
        unless ( $lines->[0] =~ s/^\s*(\S+)\s*:(\s+|$)// ) {
            die "Bad hash line";
        }
        my $key = $1;

        # Do we have a value?
        if ( length $lines->[0] ) {

            # Yes
            $hash->{$key} = $self->_read_scalar(
                shift(@$lines), [ @$indent, undef ],
                $lines
            );
        }
        else {

            # An indent
            shift @$lines;
            if ( $lines->[0] =~ /^(\s*)-/ ) {
                $hash->{$key} = [];
                $self->_read_array(
                    $hash->{$key}, [ @$indent, length($1) ],
                    $lines
                );
            }
            elsif ( $lines->[0] =~ /^(\s*)./ ) {
                my $indent2 = length("$1");
                if ( $indent->[-1] == $indent2 ) {

                    # Null hash entry
                    $hash->{$key} = undef;
                }
                else {
                    $hash->{$key} = {};
                    $self->_read_hash(
                        $hash->{$key},
                        [ @$indent, length($1) ], $lines
                    );
                }
            }
        }
    }

    return 1;
}

# Save an object to a file
sub write {
    my $self = shift;
    my $file = shift or return $self->_error('No file name provided');

    # Write it to the file
    open( CFG, '>' . $file )
      or return $self->_error("Failed to open file '$file' for writing: $!");
    print CFG $self->write_string;
    close CFG;
}

# Save an object to a string
sub write_string {
    my $self = shift;
    return '' unless @$self;

    # Iterate over the documents
    my $indent = 0;
    my @lines  = ();
    foreach my $cursor (@$self) {
        push @lines, '---';

        # An empty document
        if ( !defined $cursor ) {

            # Do nothing

            # A scalar document
        }
        elsif ( !ref $cursor ) {
            $lines[-1] .= $self->_write_scalar($cursor);

            # A list at the root
        }
        elsif ( ref $cursor eq 'ARRAY' ) {
            push @lines, $self->_write_array( $indent, $cursor );

            # A hash at the root
        }
        elsif ( ref $cursor eq 'HASH' ) {
            push @lines, $self->_write_hash( $indent, $cursor );

        }
        else {
            die "CODE INCOMPLETE";
        }
    }

    join '', map {"$_\n"} @lines;
}

sub _write_scalar {
    my $str = $_[1];
    return '~' unless defined $str;
    if ( $str =~ /$ESCAPE_CHAR/ ) {
        $str =~ s/\\/\\\\/g;
        $str =~ s/"/\\"/g;
        $str =~ s/\n/\\n/g;
        $str =~ s/([\x00-\x1f])/\\$UNPRINTABLE[ord($1)]/ge;
        return qq{"$str"};
    }
    if ( length($str) == 0 or $str =~ /\s/ ) {
        $str =~ s/'/''/;
        return "'$str'";
    }
    return $str;
}

sub _write_array {
    my ( $self, $indent, $array ) = @_;
    my @lines = ();
    foreach my $el (@$array) {
        my $line = ( '  ' x $indent ) . '-';
        if ( !ref $el ) {
            $line .= ' ' . $self->_write_scalar($el);
            push @lines, $line;

        }
        elsif ( ref $el eq 'ARRAY' ) {
            push @lines, $line;
            push @lines, $self->_write_array( $indent + 1, $el );

        }
        elsif ( ref $el eq 'HASH' ) {
            push @lines, $line;
            push @lines, $self->_write_hash( $indent + 1, $el );

        }
        else {
            die "CODE INCOMPLETE";
        }
    }

    @lines;
}

sub _write_hash {
    my ( $self, $indent, $hash ) = @_;
    my @lines = ();
    foreach my $name ( sort keys %$hash ) {
        my $el   = $hash->{$name};
        my $line = ( '  ' x $indent ) . "$name:";
        if ( !ref $el ) {
            $line .= ' ' . $self->_write_scalar($el);
            push @lines, $line;

        }
        elsif ( ref $el eq 'ARRAY' ) {
            push @lines, $line;
            push @lines, $self->_write_array( $indent + 1, $el );

        }
        elsif ( ref $el eq 'HASH' ) {
            push @lines, $line;
            push @lines, $self->_write_hash( $indent + 1, $el );

        }
        else {
            die "CODE INCOMPLETE";
        }
    }

    @lines;
}

# Set error
sub _error {
    $errstr = $ERROR{ $_[1] } ? "$ERROR{$_[1]} ($_[1])" : $_[1];
    undef;
}

# Retrieve error
sub errstr {
    $errstr;
}

1;

__END__

=pod

=head1 NAME

TAP::Parser::YAML - Read/Write YAML files with as little code as possible

=head1 VERSION

Version 0.51

=head1 SYNOPSIS

    #############################################
    # In your file
    
    ---
    rootproperty: blah
    section:
      one: two
      three: four
      Foo: Bar
      empty: ~
    
    
    
    #############################################
    # In your program
    
    use TAP::Parser::YAML;
    
    # Create a YAML file
    my $yaml = TAP::Parser::YAML->new;
    
    # Open the config
    $yaml = TAP::Parser::YAML->read( 'file.yml' );
    
    # Reading properties
    my $root = $yaml->[0]->{rootproperty};
    my $one  = $yaml->[0]->{section}->{one};
    my $Foo  = $yaml->[0]->{section}->{Foo};
    
    # Changing data
    $yaml->[0]->{newsection} = { this => 'that' }; # Add a section
    $yaml->[0]->{section}->{Foo} = 'Not Bar!';     # Change a value
    delete $yaml->[0]->{section};                  # Delete a value or section
    
    # Add an entire document
    $yaml->[1] = [ 'foo', 'bar', 'baz' ];
    
    # Save the file
    $yaml->write( 'file.conf' );

=head1 DESCRIPTION

Note that this code is lifted directly from L<YAML::Tiny> and used with
the permission of Adam Kennedy.

B<TAP::Parser::YAML> is a perl class to read and write YAML-style files with as
little code as possible, reducing load time and memory overhead.

Most of the time it is accepted that Perl applications use a lot
of memory and modules. The B<::Tiny> family of modules is specifically
intended to provide an ultralight and zero-dependency alternative to
the standard modules.

This module is primarily for reading human-written files (like config files)
and generating very simple human-readable files. Note that I said
B<human-readable> and not B<geek-readable>. The sort of files that your
average manager or secretary should be able to look at and make sense of.

L<TAP::Parser::YAML> does not generate comments, it won't necesarily preserve the
order of your hashes, and it will normalise if reading in and writing out
again.

It only supports a very basic subset of the full YAML specification.

Usage is targetted at files like Perl's META.yml, for which a small and
easily-embeddable module would be highly useful.

Features will only be added if they are human readable, and can be written
in a few lines of code. Please don't be offended if your request is
refused. Someone has to draw the line, and for TAP::Parser::YAML that someone is me.

If you need something with more power move up to L<YAML> (4 megabytes of
memory overhead) or L<YAML::Syck> (275k, but requires libsyck and a C
compiler).

To restate, L<TAP::Parser::YAML> does B<not> preserve your comments, whitespace, or
the order of your YAML data. But it should round-trip from Perl structure
to file and back again just fine.

=head1 METHODS

=head2 new

The constructor C<new> creates and returns an empty C<TAP::Parser::YAML> object.

=head2 read $filename

The C<read> constructor reads a YAML file, and returns a new
C<TAP::Parser::YAML> object containing the contents of the file. 

Returns the object on success, or C<undef> on error.

When C<read> fails, C<TAP::Parser::YAML> sets an error message internally
you can recover via C<TAP::Parser::YAML-E<gt>errstr>. Although in B<some>
cases a failed C<read> will also set the operating system error
variable C<$!>, not all errors do and you should not rely on using
the C<$!> variable.

=head2 read_string $string;

The C<read_string> method takes as argument the contents of a YAML file
(a YAML document) as a string and returns the C<TAP::Parser::YAML> object for
it.

=head2 write $filename

The C<write> method generates the file content for the properties, and
writes it to disk to the filename specified.

Returns true on success or C<undef> on error.

=head2 write_string

Generates the file content for the object and returns it as a string.

=head2 errstr

When an error occurs, you can retrieve the error message either from the
C<$TAP::Parser::YAML::errstr> variable, or using the C<errstr()> method.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=YAML-Tiny>

=begin html

For other issues, or commercial enhancement or support, please contact
<a href="http://ali.as/">Adam Kennedy</a> directly.

=end html

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 SEE ALSO

L<YAML>, L<YAML::Syck>, L<Config::Tiny>, L<CSS::Tiny>,
L<http://use.perl.org/~Alias/journal/29427>

=head1 COPYRIGHT

Copyright 2006 - 2007 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

