package App::Prove::Plugin::Dummy2;

use strict;
use warnings;

sub import {
    main::test_log_import(@_);
}

1;
