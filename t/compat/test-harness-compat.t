#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use TAPx::Harness;
use TAPx::Harness::Compatible qw(execute_tests);
use File::Spec;

my $TEST_DIR = 't/sample-tests';
my $PER_LOOP = 4;

my $results = {
    'descriptive' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 5,
            'ok'          => 5,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    join(',', qw(
        descriptive die die_head_end die_last_minute duplicates
        head_end head_fail inc_taint junk_before_plan lone_not_bug
        no_nums no_output schwern sequence_misparse shbang_misparse
        simple simple_fail skip skip_nomsg skipall skipall_nomsg
        stdout_stderr switches taint taint_warn todo_inline
        todo_misparse too_many vms_nit
    )) => {
        'failed' => {
            't/sample-tests/die' => {
                'canon'  => '??',
                'estat'  => 1,
                'failed' => '??',
                'max'    => '??',
                'name'   => 't/sample-tests/die',
                'wstat'  => '256'
            },
            't/sample-tests/die_head_end' => {
                'canon'  => '??',
                'estat'  => 1,
                'failed' => '??',
                'max'    => '??',
                'name'   => 't/sample-tests/die_head_end',
                'wstat'  => '256'
            },
            't/sample-tests/die_last_minute' => {
                'canon'  => '??',
                'estat'  => 1,
                'failed' => 0,
                'max'    => 4,
                'name'   => 't/sample-tests/die_last_minute',
                'wstat'  => '256'
            },
            't/sample-tests/duplicates' => {
                'canon'  => '??',
                'estat'  => '',
                'failed' => '??',
                'max'    => 10,
                'name'   => 't/sample-tests/duplicates',
                'wstat'  => ''
            },
            't/sample-tests/head_fail' => {
                'canon'  => 2,
                'estat'  => '',
                'failed' => 1,
                'max'    => 4,
                'name'   => 't/sample-tests/head_fail',
                'wstat'  => ''
            },
            't/sample-tests/inc_taint' => {
                'canon'  => 1,
                'estat'  => 1,
                'failed' => 1,
                'max'    => 1,
                'name'   => 't/sample-tests/inc_taint',
                'wstat'  => '256'
            },
            't/sample-tests/no_nums' => {
                'canon'  => 3,
                'estat'  => '',
                'failed' => 1,
                'max'    => 5,
                'name'   => 't/sample-tests/no_nums',
                'wstat'  => ''
            },
            't/sample-tests/no_output' => {
                'canon'  => '??',
                'estat'  => '',
                'failed' => '??',
                'max'    => '??',
                'name'   => 't/sample-tests/no_output',
                'wstat'  => ''
            },
            't/sample-tests/simple_fail' => {
                'canon'  => '2 5',
                'estat'  => '',
                'failed' => 2,
                'max'    => 5,
                'name'   => 't/sample-tests/simple_fail',
                'wstat'  => ''
            },
            't/sample-tests/switches' => {
                'canon'  => 1,
                'estat'  => '',
                'failed' => 1,
                'max'    => 1,
                'name'   => 't/sample-tests/switches',
                'wstat'  => ''
            },
            't/sample-tests/todo_misparse' => {
                'canon'  => 1,
                'estat'  => '',
                'failed' => 1,
                'max'    => 1,
                'name'   => 't/sample-tests/todo_misparse',
                'wstat'  => ''
            },
            't/sample-tests/too_many' => {
                'canon'  => '4-7',
                'estat'  => 4,
                'failed' => 4,
                'max'    => 3,
                'name'   => 't/sample-tests/too_many',
                'wstat'  => '1024'
            },
            't/sample-tests/vms_nit' => {
                'canon'  => 1,
                'estat'  => '',
                'failed' => 1,
                'max'    => 2,
                'name'   => 't/sample-tests/vms_nit',
                'wstat'  => ''
            }
        },
        'todo' => {
            't/sample-tests/todo_inline' => {
                'canon'  => 2,
                'estat'  => '',
                'failed' => 1,
                'max'    => 2,
                'name'   => 't/sample-tests/todo_inline',
                'wstat'  => ''
            }
        },
        'totals' => {
            'bad'         => 13,
            'bonus'       => 1,
            'files'       => 29,
            'good'        => 16,
            'max'         => 78,
            'ok'          => 79,
            'skipped'     => 2,
            'sub_skipped' => 2,
            'tests'       => 29,
            'todo'        => 2
        }
        },
    'die' => {
        'failed' => {
            't/sample-tests/die' => {
                'canon'  => '??',
                'estat'  => 1,
                'failed' => '??',
                'max'    => '??',
                'name'   => 't/sample-tests/die',
                'wstat'  => '256'
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 0,
            'ok'          => 0,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'die_head_end' => {
        'failed' => {
            't/sample-tests/die_head_end' => {
                'canon'  => '??',
                'estat'  => 1,
                'failed' => '??',
                'max'    => '??',
                'name'   => 't/sample-tests/die_head_end',
                'wstat'  => '256'
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 0,
            'ok'          => 4,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'die_last_minute' => {
        'failed' => {
            't/sample-tests/die_last_minute' => {
                'canon'  => '??',
                'estat'  => 1,
                'failed' => 0,
                'max'    => 4,
                'name'   => 't/sample-tests/die_last_minute',
                'wstat'  => '256'
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 4,
            'ok'          => 4,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'duplicates' => {
        'failed' => {
            't/sample-tests/duplicates' => {
                'canon'  => '??',
                'estat'  => '',
                'failed' => '??',
                'max'    => 10,
                'name'   => 't/sample-tests/duplicates',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 10,
            'ok'          => 11,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'head_end' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 4,
            'ok'          => 4,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'head_fail' => {
        'failed' => {
            't/sample-tests/head_fail' => {
                'canon'  => 2,
                'estat'  => '',
                'failed' => 1,
                'max'    => 4,
                'name'   => 't/sample-tests/head_fail',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 4,
            'ok'          => 3,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'inc_taint' => {
        'failed' => {
            't/sample-tests/inc_taint' => {
                'canon'  => 1,
                'estat'  => 1,
                'failed' => 1,
                'max'    => 1,
                'name'   => 't/sample-tests/inc_taint',
                'wstat'  => '256'
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 1,
            'ok'          => 0,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'junk_before_plan' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 1,
            'ok'          => 1,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'lone_not_bug' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 4,
            'ok'          => 4,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'no_nums' => {
        'failed' => {
            't/sample-tests/no_nums' => {
                'canon'  => 3,
                'estat'  => '',
                'failed' => 1,
                'max'    => 5,
                'name'   => 't/sample-tests/no_nums',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 5,
            'ok'          => 4,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'no_output' => {
        'failed' => {
            't/sample-tests/no_output' => {
                'canon'  => '??',
                'estat'  => '',
                'failed' => '??',
                'max'    => '??',
                'name'   => 't/sample-tests/no_output',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 0,
            'ok'          => 0,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'schwern' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 1,
            'ok'          => 1,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'sequence_misparse' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 5,
            'ok'          => 5,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'shbang_misparse' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 2,
            'ok'          => 2,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'simple' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 5,
            'ok'          => 5,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'simple_fail' => {
        'failed' => {
            't/sample-tests/simple_fail' => {
                'canon'  => '2 5',
                'estat'  => '',
                'failed' => 2,
                'max'    => 5,
                'name'   => 't/sample-tests/simple_fail',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 5,
            'ok'          => 3,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'skip' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 5,
            'ok'          => 5,
            'skipped'     => 0,
            'sub_skipped' => 1,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'skip_nomsg' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 1,
            'ok'          => 1,
            'skipped'     => 0,
            'sub_skipped' => 1,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'skipall' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 0,
            'ok'          => 0,
            'skipped'     => 1,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'skipall_nomsg' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 0,
            'ok'          => 0,
            'skipped'     => 1,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'stdout_stderr' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 4,
            'ok'          => 4,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'switches' => {
        'failed' => {
            't/sample-tests/switches' => {
                'canon'  => 1,
                'estat'  => '',
                'failed' => 1,
                'max'    => 1,
                'name'   => 't/sample-tests/switches',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 1,
            'ok'          => 0,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'taint' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 1,
            'ok'          => 1,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'taint_warn' => {
        'failed' => {},
        'todo'   => {},
        'totals' => {
            'bad'         => 0,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 1,
            'max'         => 1,
            'ok'          => 1,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'todo_inline' => {
        'failed' => {},
        'todo'   => {
            't/sample-tests/todo_inline' => {
                'canon'  => 2,
                'estat'  => '',
                'failed' => 1,
                'max'    => 2,
                'name'   => 't/sample-tests/todo_inline',
                'wstat'  => ''
            }
        },
        'totals' => {
            'bad'         => 0,
            'bonus'       => 1,
            'files'       => 1,
            'good'        => 1,
            'max'         => 3,
            'ok'          => 3,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 2
        }
    },
    'todo_misparse' => {
        'failed' => {
            't/sample-tests/todo_misparse' => {
                'canon'  => 1,
                'estat'  => '',
                'failed' => 1,
                'max'    => 1,
                'name'   => 't/sample-tests/todo_misparse',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 1,
            'ok'          => 0,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'too_many' => {
        'failed' => {
            't/sample-tests/too_many' => {
                'canon'  => '4-7',
                'estat'  => 4,
                'failed' => 4,
                'max'    => 3,
                'name'   => 't/sample-tests/too_many',
                'wstat'  => '1024'
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 3,
            'ok'          => 7,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    },
    'vms_nit' => {
        'failed' => {
            't/sample-tests/vms_nit' => {
                'canon'  => 1,
                'estat'  => '',
                'failed' => 1,
                'max'    => 2,
                'name'   => 't/sample-tests/vms_nit',
                'wstat'  => ''
            }
        },
        'todo'   => {},
        'totals' => {
            'bad'         => 1,
            'bonus'       => 0,
            'files'       => 1,
            'good'        => 0,
            'max'         => 2,
            'ok'          => 1,
            'skipped'     => 0,
            'sub_skipped' => 0,
            'tests'       => 1,
            'todo'        => 0
        }
    }
};


my $num_tests = (keys %$results) * $PER_LOOP;

plan tests => $num_tests;

SKIP: {
    skip "Not working on Windows yet", $num_tests if $^O =~ /^(MS)?Win32$/;

    {
        # Suppress subroutine redefined warning
        no warnings 'redefine';
    
        # Silence harness output
        *TAPx::Harness::output = sub {
            # do nothing
        };
    }

    for my $test_key (sort keys %$results) {
        my $result = $results->{$test_key};
        my @test_names = split(/,/, $test_key);
        my @test_files = map { File::Spec->catfile( $TEST_DIR, $_ ) } @test_names;
    
        my ($tot, $fail, $todo, $harness, $aggregate) = execute_tests( tests => \@test_files );

        my $bench = delete $tot->{bench};
        isa_ok $bench, 'Benchmark';
    
        is_deeply $tot,  $result->{totals}, "totals match for $test_key";
        is_deeply $fail, $result->{failed}, "failure summary matches for $test_key";
        is_deeply $todo, $result->{todo},   "todo summary matches for $test_key";
    }
}