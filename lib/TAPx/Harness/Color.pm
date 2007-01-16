package TAPx::Harness::Color;

use strict;
use warnings;

use TAPx::Parser;
use TAPx::Harness;

use vars qw($VERSION @ISA);
@ISA = 'TAPx::Harness';

my $NO_COLOR;
BEGIN {
    eval 'use Term::ANSIColor';
    $NO_COLOR = $@ if $@;
}

=head1 NAME

TAPx::Harness::Color - Run Perl test scripts with color

=head1 VERSION

Version 0.50_06

=cut

$VERSION = '0.50_06';

=head1 DESCRIPTION

Note that this harness is I<experimental>.  You may not like the colors I've
chosen and I haven't yet provided an easy way to override them.

This test harness is the same as C<TAPx::Harness>, but test results are output
in color.  Passing tests are printed in green.  Failing tests are in red.
Skipped tests are blue on a white background and TODO tests are printed in
white.

If C<Term::ANSIColor> cannot be found, tests will be run without color.

=head1 SYNOPSIS

 use TAPx::Harness::Color;
 my $harness = TAPx::Harness::Color->new( \%args );
 $harness->runtests(@tests);

=head1 METHODS

=head2 Class methods

=head3 C<new>

 my %args = (
    verbose => 1,
    lib     => [ 'lib', 'blib/lib' ],
    shuffle => 0,
 )
 my $harness = TAPx::Harness::Color->new( \%args );

The constructor returns a new C<TAPx::Harness::Color> object.  If
C<Term::ANSIColor> is not installed, returns a C<TAPx::Harness> object.  See
C<TAPx::Harness> for more details.

=cut

sub new {
    my $class = shift;
    if ( $NO_COLOR ) {
        warn "Cannot run tests in color: $NO_COLOR";
        return TAPx::Harness->new(@_);
    }
    return $class->SUPER::new(@_);
}

##############################################################################

=head3 C<failure_output>

  $harness->failure_output(@list_of_strings_to_output);

Overrides L<TAPx::Harness> C<failure_output> to output failure information in
red.

=cut

sub failure_output {
    my $self = shift;
    $self->output(color 'red');
    $self->output(@_);
    $self->output( color 'reset' );
}

sub _process {
    my ( $self, $result ) = @_;
    $self->output( color 'reset' );
    return unless $self->_should_display($result);

    if ( $result->is_test ) {
        if ( !$result->is_ok ) {    # even if it's TODO
            $self->output(color 'red');
        }
        elsif ( $result->has_skip ) {
            $self->output(color 'white on_blue');

        }
        elsif ( $result->has_todo ) {
            $self->output(color 'white');
        }
    }
    $self->output($result->as_string);
    $self->output(color 'reset');
    $self->output("\n");
}

1;
