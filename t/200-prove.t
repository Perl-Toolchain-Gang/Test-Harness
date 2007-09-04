use strict;
use Test::More;
use App::Prove;

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

my ( @ATTR, %DEFAULT_ASSERTION, @SCHEDULE );

BEGIN {
    @ATTR = qw(
      archive argv blib color default_formatter directives exec failures
      formatter harness includes lib merge parse quiet really_quiet
      recurse backwards shuffle taint_fail taint_warn verbose
      warnings_fail warnings_warn
    );

    %DEFAULT_ASSERTION = map { $_ => undef } @ATTR;

    $DEFAULT_ASSERTION{default_formatter} = 'TAP::Harness::Formatter::Basic';

    $DEFAULT_ASSERTION{includes} = $DEFAULT_ASSERTION{argv}
      = sub { 'ARRAY' eq ref shift };

    @SCHEDULE = (
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
                failures          => 7,
                formatter         => 8,
                harness           => 9,
                includes          => [qw(four five six)],
                lib               => 10,
                merge             => 11,
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
                failures          => 7,
                formatter         => 8,
                harness           => 9,
                includes          => [qw(four five six)],
                lib               => 10,
                merge             => 11,
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
                    'one',
                    'two',
                    'three'
                ]
            ],
        },

        # {   name => 'Just archive',
        #     args => {
        #         argv    => [qw( one two three )],
        #         archive => 1,
        #     },
        #     expect => {
        #         archive => 1,
        #     },
        #     runlog => [
        #         [   {   archive => 1,
        #             },
        #             'TAP::Harness',
        #             'one', 'two',
        #             'three'
        #         ]
        #     ],
        # },
        {   name => 'Just argv',
            args => {
                argv => [qw( one two three )],
            },
            expect => {
                argv => [qw( one two three )],
            },
            runlog => [
                [   {},
                    'TAP::Harness',
                    'one', 'two',
                    'three'
                ]
            ],
        },
        {   name => 'Just blib',
            args => {
                argv => [qw( one two three )],
                blib => 1,
            },
            expect => {
                blib => 1,
            },
            runlog => [
                [   { 'lib' => ['blib/lib'] },
                    'TAP::Harness',
                    'one',
                    'two',
                    'three'
                ]
            ],
        },
        {   name => 'Just color',
            args => {
                argv  => [qw( one two three )],
                color => 1,
            },
            expect => {
                color => 1,
            },
            runlog => [
                [   {},
                    'TAP::Harness::Color',
                    'one',
                    'two',
                    'three'
                ]
            ],
        },

      # {   name => 'Just default_formatter',
      #     args => {
      #         argv => [qw( one two three )],
      #         default_formatter => 'TAP::Harness::Formatter::Basic',
      #     },
      #     expect => {
      #         default_formatter => 'TAP::Harness::Formatter::Basic',
      #     },
      #     runlog => [
      #         [   {   default_formatter => 'TAP::Harness::Formatter::Basic',
      #             },
      #             'TAP::Harness',
      #             'one', 'two',
      #             'three'
      #         ]
      #     ],
      # },
        {   name => 'Just directives',
            args => {
                argv       => [qw( one two three )],
                directives => 1,
            },
            expect => {
                directives => 1,
            },
            runlog => [
                [   {   directives => 1,
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just exec',
            args => {
                argv => [qw( one two three )],
                exec => 1,
            },
            expect => {
                exec => 1,
            },
            runlog => [
                [   {   exec => [1],
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just failures',
            args => {
                argv     => [qw( one two three )],
                failures => 1,
            },
            expect => {
                failures => 1,
            },
            runlog => [
                [   {   failures => 1,
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        # {   name => 'Just formatter',
        #     args => {
        #         argv      => [qw( one two three )],
        #         formatter => 'TAP::Harness',
        #     },
        #     expect => {
        #         formatter => 'TAP::Harness',
        #     },
        #     runlog => [
        #         [   {   formatter => 'TAP::Harness',
        #             },
        #             'TAP::Harness',
        #             'one', 'two', 'three'
        #         ]
        #     ],
        # },
        {   name => 'Just harness',
            args => {
                argv    => [qw( one two three )],
                harness => 'TAP::Harness::Color',
            },
            expect => {
                harness => 'TAP::Harness::Color',
            },
            runlog => [
                [   {},
                    'TAP::Harness::Color',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just includes',
            args => {
                argv     => [qw( one two three )],
                includes => [qw( four five six )],
            },
            expect => {
                includes => [qw( four five six )],
            },
            runlog => [
                [   {   lib => [qw( four five six )],
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just lib',
            args => {
                argv => [qw( one two three )],
                lib  => 1,
            },
            expect => {
                lib => 1,
            },
            runlog => [
                [   { lib => ['lib'], },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just merge',
            args => {
                argv  => [qw( one two three )],
                merge => 1,
            },
            expect => {
                merge => 1,
            },
            runlog => [
                [   {   merge => 1,
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just parse',
            args => {
                argv  => [qw( one two three )],
                parse => 1,
            },
            expect => {
                parse => 1,
            },
            runlog => [
                [   { errors => 1, },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just quiet',
            args => {
                argv  => [qw( one two three )],
                quiet => 1,
            },
            expect => {
                quiet => 1,
            },
            runlog => [
                [   {   quiet => 1,
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just really_quiet',
            args => {
                argv         => [qw( one two three )],
                really_quiet => 1,
            },
            expect => {
                really_quiet => 1,
            },
            runlog => [
                [   {   really_quiet => 1,
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just recurse',
            args => {
                argv    => [qw( one two three )],
                recurse => 1,
            },
            expect => {
                recurse => 1,
            },
            runlog => [
                [   {},
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just reverse',
            args => {
                argv      => [qw( one two three )],
                backwards => 1,
            },
            expect => {
                backwards => 1,
            },
            runlog => [
                [   {},
                    'TAP::Harness',
                    'three', 'two', 'one'
                ]
            ],
        },

        # {   name => 'Just shuffle',
        #     args => {
        #         argv    => [qw( one two three )],
        #         shuffle => 1,
        #     },
        #     expect => {
        #         shuffle => 1,
        #     },
        #     runlog => [
        #         [   {   shuffle => 1,
        #             },
        #             'TAP::Harness',
        #             'one', 'two', 'three'
        #         ]
        #     ],
        # },
        {   name => 'Just taint_fail',
            args => {
                argv       => [qw( one two three )],
                taint_fail => 1,
            },
            expect => {
                taint_fail => 1,
            },
            runlog => [
                [   { 'switches' => ['T'] },
                    'TAP::Harness',
                    'one',
                    'two',
                    'three'
                ]
            ],
        },
        {   name => 'Just taint_warn',
            args => {
                argv       => [qw( one two three )],
                taint_warn => 1,
            },
            expect => {
                taint_warn => 1,
            },
            runlog => [
                [   { 'switches' => ['t'] },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just verbose',
            args => {
                argv    => [qw( one two three )],
                verbose => 1,
            },
            expect => {
                verbose => 1,
            },
            runlog => [
                [   {   verbose => 1,
                    },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just warnings_fail',
            args => {
                argv          => [qw( one two three )],
                warnings_fail => 1,
            },
            expect => {
                warnings_fail => 1,
            },
            runlog => [
                [   { 'switches' => ['W'] },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
        {   name => 'Just warnings_warn',
            args => {
                argv          => [qw( one two three )],
                warnings_warn => 1,
            },
            expect => {
                warnings_warn => 1,
            },
            runlog => [
                [   { 'switches' => ['w'] },
                    'TAP::Harness',
                    'one', 'two', 'three'
                ]
            ],
        },
    );

    my $extra_plan = 0;
    for my $test (@SCHEDULE) {
        $extra_plan += $test->{plan} || 0;
        $extra_plan += 2 if $test->{runlog};
    }

    plan tests => @SCHEDULE * ( 3 + @ATTR ) + $extra_plan;
}

for my $test (@SCHEDULE) {
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
        eval { $app->run };
        if ( my $err_pattern = $test->{run_error} ) {
            like $@, $err_pattern, "$name: expected error OK";
            pass;
        }
        else {
            unless ( ok !$@, "$name: no error OK" ) {
                diag "$name: error: $@\n";
            }
            my @gotlog = $app->get_log;
            unless ( is_deeply \@gotlog, $runlog, "$name: run results match" )
            {
                use Data::Dumper;
                diag Dumper( { wanted => $runlog, got => \@gotlog } );
            }
        }
    }
}
