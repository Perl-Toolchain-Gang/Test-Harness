# subclass for testing customizing & subclassing

package MyResultFactory;

use strict;
use vars '@ISA';

use MyCustom;
use MyResult;
use TAP::Parser::ResultFactory;

@ISA = qw( TAP::Parser::ResultFactory MyCustom );

sub new {
    my $class = shift;
    return MyResult->new(@_);
}

1;
