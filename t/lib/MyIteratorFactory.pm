# subclass for testing customizing & subclassing

package MyIteratorFactory;

use strict;
use vars '@ISA';

use MyCustom;
use MyIterator;
use TAP::Parser::IteratorFactory;

@ISA = qw( TAP::Parser::IteratorFactory MyCustom );

sub new {
    my $class = shift;
    return MyIterator->new(@_);
}

1;
