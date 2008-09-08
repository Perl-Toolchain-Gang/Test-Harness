#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Path;
use Fcntl ':flock';
use IPC::Run qw( run );
use Mail::Send;
use Getopt::Long;
use Sys::Hostname;
use YAML qw( DumpFile LoadFile );

my $VERSION = 0.006;

# Reopen STDIN.
my $pty;
unless ( $^O =~ /netbsd/ ) {
    require IO::Pty;
    $pty = IO::Pty->new;
    open( STDIN, "<&" . $pty->slave->fileno() )
      || die "Couldn't reopen STDIN for reading, $!\n";
}

GetOptions(
    'v|verbose' => \my $VERBOSE,
    'force'     => \my $FORCE
);

die "smoke.pl [-v] [--force] config\n" unless @ARGV == 1;
my $config = shift;
die "No file $config\n" unless -f $config;

my $lock = "$config.lck";
open my $lh, '>', $lock or die "Can't write $lock ($!)\n";
flock( $lh, LOCK_EX | LOCK_NB ) or exit;

my $Config = load_config($config);
my $Status = load_config( $Config->{global}->{status} );

my $SHELL = $Config->{global}->{shell} || 'bash';

for my $task ( @{ $Config->{tasks} } ) {
    test_and_report($task);
}

unlink $lock;

sub load_config {
    my ($name) = @_;
    return -f $name ? LoadFile($name) : {};
}

sub save_config {
    my ( $name, $config ) = @_;
    DumpFile( $name, $config );
}

sub mention {
    return unless $VERBOSE;
    print join( '', @_ ), "\n";
}

sub get_revision {
    my $task = shift;
    my @cmd  = ( $Config->{global}->{svn}, 'info', $task );
    my $cmd  = join( ' ', @cmd );
    my $rev  = undef;
    open my $svn, '-|', @cmd or die "Can't $cmd ($!)\n";
    while (<$svn>) {
        chomp;
        if (/^Revision:\s+(\d+)/) {
            $rev = $1;
        }
    }
    close $svn or die "Can't $cmd ($!)\n";
    return $rev;
}

sub perl_version {
    my $interp = shift;
    return unless defined $interp;
    my @cmd = ( $interp, '-MConfig', '-e', 'print $Config{version}' );
    my $cmd = join( ' ', @cmd );
    my $ver = undef;
    open my $perl, '-|', @cmd or die "Can't $cmd ($!)\n";
    $ver = <$perl>;
    close $perl or die "Can't $cmd ($!)\n";
    return $ver;
}

sub fail_pass { $_[0] ? 'PASS' : 'FAIL' }

sub test_and_report {
    my $task   = shift;
    my $name   = $task->{name};
    my $Status = $Status->{$name} ||= {};

    mention("Checking $name");

    my $cur_rev = get_revision( $task->{svn} );

    mention( "Last tested: ", $Status->{revision} )
      if exists $Status->{revision};
    mention( "Current:     ", $cur_rev );

    return
      if !$FORCE
          && exists $Status->{revision}
          && $Status->{revision} == $cur_rev;

    my @results = ();
    my $failed  = 0;

    for my $perl ( @{ $Config->{global}->{perls} } ) {
        $perl = { interp => $perl } unless 'HASH' eq ref $perl;
        for my $interp ( glob( $perl->{interp} ) ) {
            my $version = perl_version($interp);
            if ( defined $version ) {
                mention("Testing against $interp ($version)");
                my $rv = test_against_perl(
                    $version, $interp, $task, $cur_rev,
                    $perl->{desc}
                );
                $failed += $rv->{failed};
                push @results, $rv;
            }
        }
    }

    return unless @results;

    my $mailto = $task->{mailto};

    for my $mail ( 'ARRAY' eq ref $mailto ? @$mailto : ($mailto) ) {
        $mail = { email => $mail } unless 'HASH' eq ref $mail;

        my $filter = $mail->{filter} || 'all';

        die "Illegal filter spec: $filter\n"
          unless $filter =~ /^all|passed|failed$/;

        my $verbose = exists $mail->{verbose} ? $mail->{verbose} : $failed;
        my $to      = $mail->{email};
        my @to      = 'ARRAY' eq ref $to ? @$to : ($to);

        next
          unless $filter eq 'all'
              || $filter eq ( $failed ? 'failed' : 'passed' );

        my $msg = Mail::Send->new;
        $msg->to(@to);
        $msg->subject( fail_pass( !$failed )
              . ": Test report for $task->{name} r$cur_rev ("
              . hostname
              . ")" );

        my $fh = $msg->open( @{ $Config->{global}->{mailargs} || [] } );

        print $fh "To obtain this release use the following command:\n\n";
        print $fh "  svn checkout -r$cur_rev $task->{svn}\n\n";

        if ( my $desc = $Config->{global}->{description} ) {
            print $fh sprintf(
                "Tests run by smoke.pl $VERSION on %s which is a %s.\n\n",
                hostname,
                $desc
            );
        }

        for my $result (@results) {
            print $fh $result->{title}, "\n\n";

            for my $cmd ( @{ $result->{commands} } ) {
                print $fh sprintf(
                    "%s: %s\n", fail_pass( $cmd->{passed} ),
                    $cmd->{cmd}
                );
                if ($verbose) {
                    print $fh '  ', $_, "\n" for @{ $cmd->{output} };
                    print $fh '  Status: ', $cmd->{status}, "\n\n";
                }
            }

            if ($verbose) {
                print $fh $result->{env};
            }

            print $fh "\n";
        }

        $fh->close;

        mention( "Mail sent to ", join( ', ', @to ) );
    }

    $Status->{revision} = $cur_rev;
}

sub work_dir {
    my ( $task, $version, $desc ) = @_;
    my $name = $task->{name};
    if ( defined $desc ) {
        $desc =~ s/\W+/_/g;
        $version = join( '_', $version, $desc );
    }
    return File::Spec->catdir(
        $Config->{global}->{work}, $version,
        split /::/,                $name
    );
}

sub checkout {
    my $task = shift;
    my $rev  = shift;
    my @svn  = (
        $Config->{global}->{svn}, 'checkout',
        ( defined $rev ? ("-r$rev") : () ), $task->{svn}
    );
    my $result = capture_command(@svn);
    die join( ' ', @svn ), " failed: $result->{status}"
      if $result->{status};
}

sub expand {
    my ( $str, $bind ) = @_;
    $str =~ s/%(\w+)%/$bind->{$1} || "%$1%"/eg;
    return $str;
}

sub test_against_perl {
    my ( $version, $interp, $task, $rev, $desc ) = @_;
    my $work = work_dir( $task, $version, $desc );

    rmtree($work) if -d $work;
    mkpath($work);

    chdir($work);
    checkout( $task, $rev );

    my $build_dir = File::Spec->catdir( $work, $task->{subdir} );
    chdir($build_dir);

    my $bind = {
        %{ $Config->{global} },
        PERL => $interp,
        REV  => $rev,
    };

    # Doesn't work in 5.0.5
    local $ENV{PERL_MM_USE_DEFAULT} = 1;

    $desc = $desc ? "($desc) " : "";

    my $rv = {
        bind  => $bind,
        title => "=== Test against perl $version $desc==="
    };

    my $failed = 0;
    my $ok     = run_commands(
        $task->{script},
        $bind,
        sub {
            my ( $passed, $cmd, $results ) = @_;
            $failed++ unless $passed;
            push @{ $rv->{commands} },
              { passed => $passed,
                cmd    => $cmd,
                %{$results}
              };

            return $passed;
        }
    );

    my @out = ();
    for my $cmd ( 'uname -a', '%PERL% -V' ) {
        my $cooked = expand( $cmd, $bind );
        push @out, $cooked;
        my $results = capture_command( $SHELL, '-c', $cooked );
        push @out, ( map {"  $_"} @{ $results->{output} } ), '';
    }

    $rv->{env} = join "\n", @out;
    $rv->{failed} = $failed;

    return $rv;
}

sub run_commands {
    my ( $commands, $bind, $feedback ) = @_;
    for my $step (@$commands) {

        my ( $cmd, $check )
          = 'ARRAY' eq ref $step
          ? @$step
          : ( $step, sub {1} );

        my $cooked = expand( $cmd, $bind );
        my $results = capture_command( $SHELL, '-c', $cooked );

        return
          unless $feedback->(
            ( $results->{status} == 0 && $check->($results) ) ? 1 : 0,
            $cooked, $results
          );
    }

    return 1;
}

sub capture_command {
    my @cmd = @_;
    my $cmd = join ' ', @cmd;

    mention($cmd);

    my @lines = ();

    my $got_chunk = sub {
        my ( $type, $line ) = @_;
        push @lines, map {"$type| $_"} split /\n/, $line;
        mention( $lines[-1] );
    };

    run(\@cmd,
        '>',
        sub { $got_chunk->( 'O', @_ ) },
        '2>',
        sub { $got_chunk->( 'E', @_ ) }
    );

    return {
        status => $?,
        output => \@lines,
    };
}

# Scan test output. Should work with both runtests (TAP::Parser) and
# prove (Test::Harness).
# Not currently used. We probably don't need to parse the test output.
sub check_test {
    my $results = shift;

    for my $line ( reverse @{ $results->{output} } ) {
        return 1 if $line =~ /successful/i;
        return 0 if $line =~ /failed/i;
    }

    # If we run out of lines something was wrong with the
    # test output - so report an error
    return 0;
}

END {
    if ( defined $Status ) {
        save_config( $Config->{global}->{status}, $Status );
    }
}
