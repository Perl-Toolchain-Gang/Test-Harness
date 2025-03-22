package TAP::Harness::Runtime;

use strict;
use warnings;

use base q (Exporter);

use Time::HiRes;

use constant HAS_TIME_HIRES => !! eval {
	require Time::HiRes;
	Time::HiRes->import (qw (time));
	1
};

use constant IS_VMS         => $^O eq q (VMS);
use constant IS_WIN32       => ($^O =~ qr (^ (MS) Win32 $)x);
use constant IS_UNIXY       => ! (IS_VMS || IS_WIN32);

my @constants = qw (
	IS_VMS
	IS_WIN32
	IS_UNIXY
	HAS_TIME_HIRES
);

our @EXPORT_OK = (
	@constants,
	HAS_TIME_HIRES ? qw (time) : (),
);

our %EXPORT_TAGS = (
	all       => \ @EXPORT_OK,
	constants => \ @constants,
);

sub import {
	my ($caller, @arguments) = @_;

	# 'time' is exported only when Time::HiRes is available
	# but can be always requested
	@arguments = grep { $_ ne q (time) } @arguments
		unless HAS_TIME_HIRES
		;

	local @_ = ($caller, @arguments);
	goto \ &Exporter::import;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

TAP::Harness::Runtime - constants to identify runtime environment

=head1 SYNOPSIS

    package My:Superb::Package;

    # import constants
    use TAP::Harness::Runtime qw (:constants);

=head1 DESCRIPTION

Module wraps runtime detection used by multiple modules into single module.

=head1 EXPORTABLE FUNCTIONS

=head2 HAS_TIME_HIRES

Constant evaluating as C<true> when module L<Time::HiRes> is importable.

=head2 IS_VMS

Constant evaluating as C<true> when running on VMS.

=head2 IS_WIN32

Constant evaluating as C<true> when running on Windows (32-bit or 64-bit)

=head2 IS_UNIXY

Constant evaluating as C<true> when running system which behaves like Unix.

=head2 time

When L<Time::HiRes> is available module reexports its C<time> function.

Symbol can be requested for import even if L<Time::HiRes> isn't available
without causing any error.

=head1 EXPORT TAGS

=head2 all

Import all exported symbols.

=head2 constants

Import all constants.

=head1 SEE ALSO

L<TAP::Harness>

=head1 BUGS

Please report any bugs or feature request at
L<https://github.com/Perl-Toolchain-Gang/Test-Harness/issues>

=head1 REPOSITORY

L<https://github.com/Perl-Toolchain-Gang/Test-Harness>

=head1 LICENCE AND COPYRIGHT

This module is free software; you can redistribute it and/or
modify it under same terms as L<Test::Harness> distribution.

