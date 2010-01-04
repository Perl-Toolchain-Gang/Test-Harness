package MyShebangger;

use strict;
use warnings;

use Config;

=head1 NAME

MyShebangger - Encapsulate EUMM / MB shebang magic

=item fixin

  $mm->fixin(@files);

Inserts the sharpbang or equivalent magic number to a set of @files.

=cut

# stolen from ExtUtils::MakeMaker which said:
# stolen from the pink Camel book, more or less
sub fixin {
    my ( $self, @files ) = @_;

    my ($does_shbang) = $Config{'sharpbang'} =~ /^\s*\#\!/;
    for my $file (@files) {
        my $file_new = "$file.new";
        my $file_bak = "$file.bak";

        open( my $fixin, '<', $file ) or croak "Can't process '$file': $!";
        local $/ = "\n";
        chomp( my $line = <$fixin> );
        next unless $line =~ s/^\s*\#!\s*//;    # Not a shbang file.
              # Now figure out the interpreter name.
        my ( $cmd, $arg ) = split ' ', $line, 2;
        $cmd =~ s!^.*/!!;

        # Now look (in reverse) for interpreter in absolute PATH
        # (unless perl).
        my $interpreter;
        if ( $cmd =~ m{^perl(?:\z|[^a-z])} ) {
            if ( $Config{startperl} =~ m,^\#!.*/perl, ) {
                $interpreter = $Config{startperl};
                $interpreter =~ s,^\#!,,;
            }
            else {
                $interpreter = $Config{perlpath};
            }
        }
        else {
            my (@absdirs)
              = reverse grep { $self->file_name_is_absolute($_) } $self->path;
            $interpreter = '';

            foreach my $dir (@absdirs) {
                if ( $self->maybe_command($cmd) ) {
                    $interpreter = $self->catfile( $dir, $cmd );
                }
            }
        }

        # Figure out how to invoke interpreter on this machine.

        my ($shb) = "";
        if ($interpreter) {
            # this is probably value-free on DOSISH platforms
            if ($does_shbang) {
                $shb .= "$Config{'sharpbang'}$interpreter";
                $shb .= ' ' . $arg if defined $arg;
                $shb .= "\n";
            }
            $shb .= qq{
eval 'exec $interpreter $arg -S \$0 \${1+"\$\@"}'
    if 0; # not running under some shell
} unless $Is{Win32};    # this won't work on win32, so don't
        }
        else {
            next;
        }

        open( my $fixout, ">", "$file_new" ) or do {
            warn "Can't create new $file: $!\n";
            next;
        };

        # Print out the new #! line (or equivalent).
        local $\;
        local $/;
        print $fixout $shb, <$fixin>;
        close $fixin;
        close $fixout;

        chmod 0666, $file_bak;
        unlink $file_bak;
        unless ( _rename( $file, $file_bak ) ) {
            warn "Can't rename $file to $file_bak: $!";
            next;
        }
        unless ( _rename( $file_new, $file ) ) {
            warn "Can't rename $file_new to $file: $!";
            unless ( _rename( $file_bak, $file ) ) {
                warn "Can't rename $file_bak back to $file either: $!";
                warn "Leaving $file renamed as $file_bak\n";
            }
            next;
        }
        unlink $file_bak;
    }
    continue {
        system("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
    }
}

sub _rename {
    my ( $old, $new ) = @_;

    foreach my $file ( $old, $new ) {
        if ( $Is{VMS} and basename($file) !~ /\./ ) {

            # rename() in 5.8.0 on VMS will not rename a file if it
            # does not contain a dot yet it returns success.
            $file = "$file.";
        }
    }

    return rename( $old, $new );
}

1;
