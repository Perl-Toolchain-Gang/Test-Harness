#!/usr/bin/perl -w

use strict;
use Test::More (
    $^O eq 'VMS'
    ? ( skip_all => 'VMS' )
    : ( tests => 12 )
);

use Test::Harness;
{
    # Should add a fake home dir? to test the rc stuff..
    local $ENV{HARNESS_OPTIONS} = 'j4:c';

    ok my $harness = Test::Harness::_new_harness, 'made harness';
    is($harness->color, 1, "set color correctly");
    is($harness->jobs, 4, "set jobs correctly");
}
{
    local $ENV{HARNESS_OPTIONS} = 'j4:c:fTAP-Formatter-SocketConsole';

    ok my $harness = Test::Harness::_new_harness, 'made harness';
    is($harness->color, 1, "set color correctly");
    is($harness->jobs, 4, "set jobs correctly");
    is($harness->formatter_class, "TAP::Formatter::SocketConsole", "correct formatter");

}
{
    # Test archive
    local $ENV{HARNESS_OPTIONS} = 'j4:c:a/archive.tgz';

    ok my $harness = Test::Harness::_new_harness, 'made harness';
    is($harness->color, 1, "set color correctly");
    is($harness->jobs, 4, "set jobs correctly");
    isa_ok($harness, "TAP::Harness::Archive", "correct harness subclass");
    # XXX: this is nasty :(
    is($harness->{__archive_file}, "/archive.tgz", "correct archive found");

}

