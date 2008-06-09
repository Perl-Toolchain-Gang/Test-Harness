package TAP::Parser::ResultFactory;

use strict;
use vars qw($VERSION @ISA %CLASS_FOR);

use TAP::Object                  ();
use TAP::Parser::Result::Bailout ();
use TAP::Parser::Result::Comment ();
use TAP::Parser::Result::Plan    ();
use TAP::Parser::Result::Pragma  ();
use TAP::Parser::Result::Test    ();
use TAP::Parser::Result::Unknown ();
use TAP::Parser::Result::Version ();
use TAP::Parser::Result::YAML    ();

@ISA = 'TAP::Object';

##############################################################################

=head1 NAME

TAP::Parser::ResultFactory - Factory for creating TAP::Parser output objects

=head1 VERSION

Version 3.12

=cut

$VERSION = '3.12';

=head2 DESCRIPTION

This is merely a factory class which returns a L<TAP::Parser::Result> subclass
representing the current bit of test data from TAP (usually a line).  It is
used primarily by L<TAP::Parser::Grammar>.

=head2 METHODS

=head3 new

Returns an instance the appropriate class for the test token passed in.

  my $result = TAP::Parser::ResultFactory->new($token);

=cut

# override new() to do some custom factory class action...

sub new {
    my ( $class, $token ) = @_;
    my $type = $token->{type};

    # TODO: call $CLASS_FOR{$type}->new !

    # bless their token into the target class:
    return bless $token => $CLASS_FOR{$type}
      if exists $CLASS_FOR{$type};

    # or complain:
    require Carp;
    Carp::croak("Could not determine class for\n$token->{type}");
}


=head3 register_type

This lets you override an existing type with your own custom type, or register
a completely new type, eg:

  # create a custom result type:
  package MyResult;
  use strict;
  use vars qw($VERSION @ISA);
  @ISA = 'TAP::Parser::Result';

  # register with the factory:
  TAP::Parser::ResultFactory->register_type( 'my_type' => __PACKAGE__ );

  # use it:
  my $r = TAP::Parser::ResultFactory->( { type => 'my_type' } );

Your custom type should then be picked up automatically by the L<TAP::Parser>.

=cut

BEGIN {
    %CLASS_FOR = (
        plan    => 'TAP::Parser::Result::Plan',
        pragma  => 'TAP::Parser::Result::Pragma',
        test    => 'TAP::Parser::Result::Test',
        comment => 'TAP::Parser::Result::Comment',
        bailout => 'TAP::Parser::Result::Bailout',
        version => 'TAP::Parser::Result::Version',
        unknown => 'TAP::Parser::Result::Unknown',
        yaml    => 'TAP::Parser::Result::YAML',
    );
}

sub register_type {
    my ( $class, $type, $rclass ) = @_;
    # register it blindly, assume they know what they're doing
    $CLASS_FOR{$type} = $rclass;
    return $class;
}

1;

=head1 SEE ALSO

L<TAP::Parser>,
L<TAP::Parser::Result>,
L<TAP::Parser::Grammar>

=cut
