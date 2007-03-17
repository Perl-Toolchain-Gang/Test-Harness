#!/usr/bin/perl -wT

use Test::More tests => 40;

BEGIN {
    my @classes = qw(
      TAP::Parser
      TAP::Parser::Aggregator
      TAP::Parser::Grammar
      TAP::Parser::Iterator::Array
      TAP::Parser::Iterator::Process
      TAP::Parser::Iterator::Stream
      TAP::Parser::Result
      TAP::Parser::Result::Comment
      TAP::Parser::Result::Plan
      TAP::Parser::Result::Test
      TAP::Parser::Result::Unknown
      TAP::Parser::Result::Bailout
      TAP::Parser::Result::Version
      TAP::Parser::Source
      TAP::Parser::Source::Perl
      TAP::Parser::YAMLish::Reader
      TAP::Parser::YAMLish::Writer
      TAP::Harness
      TAP::Harness::Color
      TAP::Base
    );

    foreach my $class (@classes) {
        use_ok $class;
        is $class->VERSION, TAP::Parser->VERSION,
          "... and it should have the correct version";
    }
    diag("Testing TAP::Parser $TAP::Parser::VERSION, Perl $], $^X");
}
