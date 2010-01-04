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
    my ( $file_in, $file_out ) = @_;

    my ($does_shbang) = $Config{'sharpbang'} =~ /^\s*\#\!/;

    open my $fixin, '<', $file_in or die "Can't process '$file_in': $!";
    local $/ = "\n";
    chomp( my $line = <$fixin> );

    die "$file_in doesn't have a shebang line"
      unless $line =~ s/^\s*\#!\s*//;

    # Now figure out the interpreter name.
    my ( $cmd, $arg ) = split ' ', $line, 2;
    $cmd =~ s!^.*/!!;

    my $interpreter;

    die "$file_in is not perl"
      unless $cmd =~ m{^perl(?:\z|[^a-z])};

    if ( $Config{startperl} =~ m,^\#!.*/perl, ) {
        $interpreter = $Config{startperl};
        $interpreter =~ s,^\#!,,;
    }
    else {
        $interpreter = $Config{perlpath};
    }

    die "Can't figure out which interpreter to use."
      unless defined $interpreter;

    # Figure out how to invoke interpreter on this machine.
    my $shb = '';

    # this is probably value-free on DOSISH platforms
    if ($does_shbang) {
        $shb .= "$Config{'sharpbang'}$interpreter";
        $shb .= ' ' . $arg if defined $arg;
        $shb .= "\n";
    }
    $shb .= qq{
eval 'exec $interpreter $arg -S \$0 \${1+"\$\@"}'
    if 0; # not running under some shell
} unless $^O eq 'MSWin32';    # this won't work on win32, so don't

    open my $fixout, ">", "$file_out"
      or die "Can't create new $file: $!\n";

    # Print out the new #! line (or equivalent).
    local $\;
    local $/;
    print $fixout $shb, <$fixin>;
    close $fixin;
    close $fixout;

    system("$Config{'eunicefix'} $file_out") if $Config{'eunicefix'} ne ':';
}

sub _rename {
    my ( $old, $new ) = @_;

    for my $file ( $old, $new ) {
        if ( $Is{VMS} and basename($file) !~ /\./ ) {

            # rename() in 5.8.0 on VMS will not rename a file if it
            # does not contain a dot yet it returns success.
            $file = "$file.";
        }
    }

    return rename( $old, $new );
}

1;
