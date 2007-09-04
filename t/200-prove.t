use strict;
use Test::More;
use App::Prove;

my @schedule;

package FakeProve;
use vars qw( @ISA );

@ISA = qw( App::Prove );

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{_log} = [];
    return $self;
}

sub _runtests {
    my ( $self, $args, $harness_class, @tests ) = @_;
    push @{ $self->{_log} }, [ $args, $harness_class, @tests ];
}

sub get_log {
    my $self = shift;
    my @log  = @{ $self->{_log} };
    $self->{_log} = [];
    return @log;
}

package main;

my @ATTR;
my %DEFAULT_ASSERTION;

BEGIN {
    @ATTR = qw(
      archive argv blib color default_formatter directives exec extension
      failures formatter harness includes lib merge options parse quiet
      really_quiet recurse backwards shuffle taint_fail taint_warn verbose
      warnings_fail warnings_warn
    );

    %DEFAULT_ASSERTION = map { $_ => undef } @ATTR;

    $DEFAULT_ASSERTION{default_formatter} = 'TAP::Harness::Formatter::Basic';

    $DEFAULT_ASSERTION{includes} = $DEFAULT_ASSERTION{argv}
      = sub { 'ARRAY' eq ref shift };

    @schedule = (
        {   name   => 'Create empty',
            expect => {}
        },
        {   name => 'Set all options via constructor',
            args => {
                archive           => 1,
                argv              => [qw(one two three)],
                blib              => 2,
                color             => 3,
                default_formatter => 'some formatter',
                directives        => 4,
                exec              => 5,
                extension         => 6,
                failures          => 7,
                formatter         => 8,
                harness           => 9,
                includes          => [qw(four five six)],
                lib               => 10,
                merge             => 11,
                options           => 12,
                parse             => 13,
                quiet             => 14,
                really_quiet      => 15,
                recurse           => 16,
                backwards         => 17,
                shuffle           => 18,
                taint_fail        => 19,
                taint_warn        => 20,
                verbose           => 21,
                warnings_fail     => 22,
                warnings_warn     => 23,
            },
            expect => {
                archive           => 1,
                argv              => [qw(one two three)],
                blib              => 2,
                color             => 3,
                default_formatter => 'some formatter',
                directives        => 4,
                exec              => 5,
                extension         => 6,
                failures          => 7,
                formatter         => 8,
                harness           => 9,
                includes          => [qw(four five six)],
                lib               => 10,
                merge             => 11,
                options           => 12,
                parse             => 13,
                quiet             => 14,
                really_quiet      => 15,
                recurse           => 16,
                backwards         => 17,
                shuffle           => 18,
                taint_fail        => 19,
                taint_warn        => 20,
                verbose           => 21,
                warnings_fail     => 22,
                warnings_warn     => 23,
            }
        },
        {   name   => 'Call with defaults',
            args   => { argv => [qw( one two three )] },
            expect => {},
            runlog => [
                [   {},
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
    );

    my $extra_plan = 0;
    for my $test (@schedule) {
        $extra_plan += $test->{plan} || 0;
        $extra_plan++ if $test->{runlog};
    }

    plan tests => @schedule * ( 3 + @ATTR ) + $extra_plan;
}

for my $test (@schedule) {
    my $name = $test->{name};
    my $class = $test->{class} || 'FakeProve';

    ok my $app = $class->new( exists $test->{args} ? $test->{args} : () ),
      "$name: App::Prove created OK";

    isa_ok $app, 'App::Prove';
    isa_ok $app, $class;

    my $expect = $test->{expect} || {};
    for my $attr ( sort @ATTR ) {
        my $val       = $app->$attr();
        my $assertion = $expect->{$attr} || $DEFAULT_ASSERTION{$attr};
        my $is_ok     = undef;
        if ( 'CODE' eq ref $assertion ) {
            $is_ok = ok $assertion->( $val, $attr ),
              "$name: $attr has the expected value";
        }
        elsif ( 'Regexp' eq ref $assertion ) {
            $is_ok = like $val, $assertion, "$name: $attr matches $assertion";
        }
        else {
            $is_ok = is_deeply $val, $assertion,
              "$name: $attr has the expected value";
        }

        unless ($is_ok) {
            diag "got $val for $attr";
        }
    }

    if ( my $runlog = $test->{runlog} ) {
        $app->run;
        my @gotlog = $app->get_log;
        unless ( is_deeply \@gotlog, $runlog, "$name: run results match" ) {
            use Data::Dumper;
            diag Dumper( { wanted => $runlog, got => \@gotlog } );
        }
    }
}
