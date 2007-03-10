package TAPx::Parser::Source::Perl;

use strict;
use vars qw($VERSION @ISA);

use constant IS_WIN32 => ( $^O =~ /^(MS)?Win32$/ );
use constant IS_MACOS => ( $^O eq 'MacOS' );
use constant IS_VMS   => ( $^O eq 'VMS' );

use TAPx::Parser::Iterator;
use TAPx::Parser::Source;
@ISA = 'TAPx::Parser::Source';

=head1 NAME

TAPx::Parser::Source::Perl - Stream Perl output

=head1 VERSION

Version 0.51

=cut

$VERSION = '0.51';

=head1 DESCRIPTION

Takes a filename and hopefully returns a stream from it.  The filename should
be the name of a Perl program.

Note that this is a subclass of L<TAPx::Parser::Source>.  See that module for
more methods.

=head1 SYNOPSIS

 use TAPx::Parser::Source::Perl;
 my $perl   = TAPx::Parser::Source::Perl->new;
 my $stream = $perl->source($filename)->get_stream;

=head1 METHODS

=head2 Class methods

=head3 C<new>

 my $perl = TAPx::Parser::Source::Perl->new;

Returns a new C<TAPx::Parser::Source::Perl> object.

=head2 Instance methods

=head3 C<source>

 my $perl = $source->source;
 $perl->source($filename);

Getter/setter for the source filename.  Will C<croak> if the C<$filename> does
not appear to be a file.

=cut

sub source {
    my $self = shift;
    return $self->{source} unless @_;
    my $filename = shift;
    unless ( -f $filename ) {
        $self->_croak("Cannot find ($filename)");
    }
    $self->{source} = $filename;
    return $self;
}

=head3 C<switches>

 my $switches = $perl->switches;
 my @switches = $perl->switches;
 $perl->switches(\@switches);

Getter/setter for the additional switches to pass to the perl executable.  One
common switch would be to set an include directory:

 $perl->switches('-Ilib');

=cut

sub switches {
    my $self = shift;
    unless (@_) {
        return wantarray ? @{ $self->{switches} } : $self->{switches};
    }
    my $switches = shift;
    $self->{switches} = [@$switches];    # force a copy
    return $self;
}

sub _get_command {
    my $self     = shift;
    my $file     = $self->source;
    my $command  = $self->_get_perl;
    my @switches = $self->_switches;

    $file = qq["$file"] if ( $file =~ /\s/ ) && ( $file !~ /^".*"$/ );
    my @command = ( $command, @switches, $file );

    #use Data::Dumper;
    #warn Dumper(\@command);
    return @command;
}

sub _switches {
    my $self     = shift;
    my $file     = $self->source;
    my @switches = (
        $self->switches,
    );

    local *TEST;
    open( TEST, $file ) or print "can't open $file. $!\n";
    my $shebang = <TEST>;
    close(TEST) or print "can't close $file. $!\n";

    my $taint = ( $shebang =~ /^#!.*\bperl.*\s-\w*([Tt]+)/ );
    push( @switches, "-$1" ) if $taint;

    # When taint mode is on, PERL5LIB is ignored.  So we need to put
    # all that on the command line as -Is.
    # MacPerl's putenv is broken, so it will not see PERL5LIB, tainted or not.
    if ( $taint || IS_MACOS ) {
        my @inc = $self->_filtered_inc;
        push @switches, map {"-I$_"} @inc;
    }

    # Quote the argument if there's any whitespace in it, or if
    # we're VMS, since VMS requires all parms quoted.  Also, don't quote
    # it if it's already quoted.
    for (@switches) {
        $_ = qq["$_"] if ( ( /\s/ || IS_VMS ) && !/^".*"$/ );
    }

    my %found_switch = map { $_ => 0 } @switches;

    # remove duplicate switches
    @switches
      = grep { defined $_ && $_ ne '' && !$found_switch{$_}++ } @switches;
    return @switches;
}

sub _filtered_inc {
    my $self = shift;
    my @inc  = @_;
    @inc = @INC unless @inc;

    if (IS_VMS) {

        # VMS has a 255-byte limit on the length of %ENV entries, so
        # toss the ones that involve perl_root, the install location
        @inc = grep !/perl_root/i, @inc;

    }
    elsif (IS_WIN32) {

        # Lose any trailing backslashes in the Win32 paths
        s/[\\\/+]$// foreach @inc;
    }

    my %seen;
    $seen{$_}++ foreach $self->_default_inc;
    @inc = grep !$seen{$_}++, @inc;

    return @inc;
}

{

    # cache this to avoid repeatedly shelling out to Perl.  This really speeds
    # up TAPx::Parser.
    my @inc;

    sub _default_inc {
        return @inc if @inc;
        my $proto = shift;
        local $ENV{PERL5LIB};
        my $perl = $proto->_get_perl;
        chomp( @inc = `$perl -le "print join qq[\\n], \@INC"` );
        return @inc;
    }
}

sub _get_perl {
    my $proto = shift;
    return $ENV{HARNESS_PERL}           if defined $ENV{HARNESS_PERL};
    return Win32::GetShortPathName($^X) if IS_WIN32;
    return $^X;
}

1;
