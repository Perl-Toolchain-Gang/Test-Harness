package NoFork;

BEGIN {
    *CORE::GLOBAL::fork = sub { die "you should not fork"};
}
use Config;
tied(%Config)->{d_fork} = 0; # blatant lie

# TEST:
# perl -Ilib -It/lib -MNoFork bin/prove t/sample-tests/simple

1;
# vim:ts=4:sw=4:et:sta
