# subclass for testing customizing & subclassing

package MyPerlSourceDetector;

use strict;
use vars '@ISA';

use MyCustom;
use TAP::Parser::SourceDetector::Perl;
use TAP::Parser::SourceFactory;

@ISA = qw( TAP::Parser::SourceDetector::Perl MyCustom );

TAP::Parser::SourceFactory->register_detector(__PACKAGE__);

sub can_handle {
    my $class = shift;
    my $vote  = $class->SUPER::can_handle(@_);
    $vote += 0.1 if $vote > 0;    # steal the Perl detector's vote
    return $vote;
}

1;

