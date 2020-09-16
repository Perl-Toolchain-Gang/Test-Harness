package NoFork;

BEGIN {
    *CORE::GLOBAL::fork = sub { die "you should not fork" };
}

$TAP::Parser::Iterator::Process::can_fork = 0;

=begin TEST

Assuming not to much chdir:

  PERL5OPT='-It/lib -MNoFork' perl -Ilib bin/prove -r t

=end TEST

=cut

1;

# vim:ts=4:sw=4:et:sta
