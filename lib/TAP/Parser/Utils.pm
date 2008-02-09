package TAP::Parser::Utils;

use strict;
use vars qw($VERSION);

=head1 NAME

TAP::Parser::Utils - Internal TAP::Parser utilities

=head1 VERSION

Version 3.09

=cut

$VERSION = '3.09';

=head1 SYNOPSIS

  use TAP::Parser::Utils;
  my @switches = TAP::Parser::Utils::split_shell_switches( $arg );

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY!>

=head2 INTERFACE

=head3 C<split_shell_switches>

Shell style argument parsing. Handles backslash escaping, single and
double quoted strings but not shell substitutions.

This is used to split HARNESS_PERL_ARGS into individual switches.

=cut

sub split_shell_switches {
    my @parts = ();

    for my $switch ( grep defined && length, @_ ) {
        push @parts, $1 while $switch =~ /
        ( 
            (?:   [^\\"'\s]+
                | \\. 
                | " (?: \\. | [^"] )* "
                | ' (?: \\. | [^'] )* ' 
            )+
        ) /xg;
    }

    my @out = ();

    for ( grep length, @parts ) {
        s/ \\(.) | ['"] /defined $1 ? $1 : ''/exg;
        push @out, $_;
    }
    return @out;
}

1;
