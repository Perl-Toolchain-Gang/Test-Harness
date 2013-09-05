#!perl -wT

use strict;
use warnings;
use lib 't/lib';

use Test::More;

# TODO skip on install?
eval "use Test::Pod 1.41";
plan skip_all => "Test::Pod 1.41 required for testing POD" if $@;
all_pod_files_ok();
