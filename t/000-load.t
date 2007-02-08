#!/usr/bin/perl -wT

use Test::More tests => 32;

BEGIN {
    my @classes = qw(
      TAPx::Parser
      TAPx::Parser::Aggregator
      TAPx::Parser::Grammar
      TAPx::Parser::Iterator
      TAPx::Parser::Result
      TAPx::Parser::Result::Comment
      TAPx::Parser::Result::Plan
      TAPx::Parser::Result::Test
      TAPx::Parser::Result::Unknown
      TAPx::Parser::Result::Bailout
      TAPx::Parser::Source
      TAPx::Parser::Source::Perl
      TAPx::Parser::YAML
      TAPx::Harness
      TAPx::Harness::Color
      TAPx::Base
    );

    foreach my $class (@classes) {
        use_ok $class;
        is $class->VERSION, TAPx::Parser->VERSION,
            "... and it should have the correct version";
    }
    diag("Testing TAPx::Parser $TAPx::Parser::VERSION, Perl $], $^X");
}
