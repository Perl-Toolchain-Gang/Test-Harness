#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Path;
use IO::Handle;
use IPC::Open3;
use IO::Select;
use Mail::Send;
use Getopt::Long;
use YAML qw( DumpFile LoadFile );

GetOptions(
    'v|verbose' => \my $VERBOSE,
    'force'     => \my $FORCE
);

die "smoke.pl [-v] [--force] config\n" unless @ARGV == 1;
my $config = shift;
die "No file $config\n" unless -f $config;
my $Config = load_config($config);
my $Status = load_config( $Config->{global}->{status} );

for my $task ( @{ $Config->{tasks} } ) {
    test_and_report($task);
}

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
    LINE: while (<$svn>) {
        chomp;
        if (/^Revision:\s+(\d+)/) {
            $rev = $1;
            last LINE;
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

    my $mailto = $task->{mailto};
    my @mailto = 'ARRAY' eq ref $mailto ? @$mailto : $mailto;

    my $msg = Mail::Send->new;
    $msg->to(@mailto);
    $msg->subject("Automated test report for $task->{name} r$cur_rev");

    my $fh = $msg->open;

    print $fh "To obtain this release use the following command:\n\n";
    print $fh "  svn checkout -r$cur_rev $task->{svn}\n";

    for my $interp ( map glob, @{ $Config->{global}->{perls} } ) {
        my $version = perl_version($interp);
        if ( defined $version ) {
            mention("Testing against $interp ($version)");
            my $chunk = test_against_perl( $version, $interp, $task );
            print $fh "\n$chunk" if $chunk;
        }
        else {
            print $fh "Can't get version of $interp\n";
        }
    }

    $fh->close;

    mention( "Mail sent to ", join( ', ', @mailto ) );

    $Status->{revision} = $cur_rev;
}

sub work_dir {
    my ( $task, $version ) = @_;
    my $name = $task->{name};
    return File::Spec->catdir(
        $Config->{global}->{work}, $version,
        split /::/,                $name
    );
}

sub checkout {
    my $task   = shift;
    my @svn    = ( $Config->{global}->{svn}, 'checkout', $task->{svn} );
    my $result = capture_command(@svn);
    die join( ' ', @svn ), " failed: $result->{status}" if $result->{status};
}

sub expand {
    my ( $str, $bind ) = @_;
    $str =~ s/%(\w+)%/$bind->{$1} || "%$1%"/eg;
    return $str;
}

sub test_against_perl {
    my ( $version, $interp, $task ) = @_;
    my $work = work_dir( $task, $version );

    my @out = ( "=== Test against perl $version ===", '' );

    rmtree($work) if -d $work;
    mkpath($work);

    chdir($work);
    checkout($task);

    my $build_dir = File::Spec->catdir( $work, $task->{subdir} );
    chdir($build_dir);

    my $bind = { PERL => $interp };

    # Doesn't work in 5.0.5
    local $ENV{PERL_MM_USE_DEFAULT} = 1;

    my $ok = run_commands(
        $task->{script},
        $bind,
        sub {
            my ( $type, $cmd, $results ) = @_;
            push @out, "$type: $cmd";
            unless ( $type eq 'passed' ) {
                push @out, @{ $results->{output} };
                push @out, "Exit status: $results->{status}", '';
                return 0;
            }
            return 1;
        }
    );

    unless ($ok) {
        push @out, '' if $out[-1];
        for my $cmd ( 'uname -a', '%PERL% -V' ) {
            my $cooked = expand( $cmd, $bind );
            push @out, $cooked;
            my $results = capture_command($cooked);
            push @out, @{ $results->{output} };
            push @out, '';
        }
    }

    return join "\n", @out, '';
}

sub run_commands {
    my ( $commands, $bind, $feedback ) = @_;
    for my $step (@$commands) {

        my ( $cmd, $check )
          = 'ARRAY' eq ref $step
          ? @$step
          : ( $step, sub {1} );

        my $cooked = expand( $cmd, $bind );
        my $results = capture_command($cooked);

        my $status
          = ( $results->{status} == 0 && $check->($results) )
          ? 'passed'
          : 'failed';

        return unless $feedback->( $status, $cooked, $results );
    }

    return 1;
}

sub capture_command {
    my @cmd = @_;
    my $cmd = join ' ', @cmd;

    mention($cmd);

    my $out = IO::Handle->new;
    my $err = IO::Handle->new;

    my $pid = eval { open3( undef, $out, $err, @cmd ) };
    die "Could not execute ($cmd): $@" if $@;

    my $sel   = IO::Select->new( $out, $err );
    my $flip  = 0;
    my @lines = ();

    # Loops forever while we're reading from STDERR
    while ( my @ready = $sel->can_read ) {

        # Load balancing :)
        @ready = reverse @ready if $flip;
        $flip = !$flip;

        for my $fh (@ready) {
            if ( defined( my $line = <$fh> ) ) {
                my $pfx = $fh == $err ? 'E' : 'O';
                chomp $line;
                push @lines, "$pfx| $line";
                mention("$pfx| $line");
            }
            else {
                $sel->remove($fh);
            }
        }
    }

    my $status = undef;
    if ( $pid == waitpid( $pid, 0 ) ) {
        $status = $?;
    }

    return {
        status => $status,
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
