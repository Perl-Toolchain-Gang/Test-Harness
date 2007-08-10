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
use YAML qw< DumpFile LoadFile >;

use constant SVN    => '/usr/bin/svn';
use constant STATUS => '/home/andy/.smoke-tapx';
use constant WORK   => '/home/andy/.smoke-work';

GetOptions( 'v|verbose' => \my $VERBOSE );

my %PERLS = (
    '5.0.5' => '/home/andy/Works/Perl/versions/5.0.5',
    '5.6.1' => '/home/andy/Works/Perl/versions/5.6.1',
    '5.6.2' => '/home/andy/Works/Perl/versions/5.6.2',
    '5.8.5' => '/home/andy/Works/Perl/versions/5.8.5',
    '5.8.6' => '/home/andy/Works/Perl/versions/5.8.6',
    '5.8.7' => '/home/andy/Works/Perl/versions/5.8.7',
    '5.8.8' => '/usr',
    '5.9.5' => '/home/andy/Works/Perl/versions/5.9.5',
);

my @CONFIG = (
    {   name   => 'TAP::Parser',
        svn    => 'http://svn.hexten.net/tapx/trunk',
        subdir => 'trunk',
        script => [
            'yes n | %PERL% Makefile.PL',
            'make',
            [ 'make test', \&check_test ],

            # Dogfood
            [ '%PERL% -Ilib bin/runtests t/*.t t/compat/*.t', \&check_test ],
        ],

        mailto => 'tapx-dev@hexten.net',
    }
);

my $Status = -f STATUS ? LoadFile(STATUS) : {};

for my $repo (@CONFIG) {
    test_and_report($repo);
}

sub mention {
    return unless $VERBOSE;
    print join( '', @_ ), "\n";
}

sub get_revision {
    my $repo = shift;
    my @cmd  = ( SVN, 'info', $repo );
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

sub test_and_report {
    my $repo   = shift;
    my $name   = $repo->{name};
    my $Status = $Status->{$name} ||= {};

    mention("Checking $name");

    my $cur_rev = get_revision( $repo->{svn} );

    mention( "Last tested: ", $Status->{revision} )
      if exists $Status->{revision};
    mention( "Current:     ", $cur_rev );

    return if exists $Status->{revision} && $Status->{revision} == $cur_rev;

    my $mailto = $repo->{mailto};
    my @mailto = 'ARRAY' eq ref $mailto ? @$mailto : $mailto;

    my $msg = Mail::Send->new;
    $msg->to(@mailto);
    $msg->subject("Automated test report for $repo->{name} r$cur_rev");

    my $fh = $msg->open;

    print $fh "To obtain this release use the following command:\n\n";
    print $fh "  svn checkout -r$cur_rev $repo->{svn}\n";

    for my $version ( sort keys %PERLS ) {
        my $path = $PERLS{$version};
        my $chunk = test_against_perl( $version, $path, $repo, $Status );
        print $fh "\n$chunk" if $chunk;
    }

    $fh->close;

    $Status->{revision} = $cur_rev;
}

sub find_perl {
    my ( $version, $path ) = @_;
    my @try = ( 'bin/perl', "bin/perl$version" );
    for my $try (@try) {
        my $interp = File::Spec->catfile(
            $path,
            split '/', $try
        );
        return $interp if -x $interp;
    }
    return;
}

sub work_dir {
    my ( $repo, $version ) = @_;
    my $name = $repo->{name};
    return File::Spec->catdir( WORK, $version, split /::/, $name );
}

sub checkout {
    my $repo   = shift;
    my @svn    = ( SVN, 'checkout', $repo->{svn} );
    my $result = capture_command(@svn);
    die join( ' ', @svn ), " failed: $result->{status}" if $result->{status};
}

sub expand {
    my ( $str, $bind ) = @_;
    $str =~ s/%(\w+)%/$bind->{$1} || "%$1%"/eg;
    return $str;
}

sub test_against_perl {
    my ( $version, $path, $repo, $Status ) = @_;
    my $interp = find_perl( $version, $path );
    my $work   = work_dir( $repo,     $version );

    my @out = ( "=== Test against perl $version ===", '' );

    rmtree($work) if -d $work;
    mkpath($work);

    chdir($work);
    checkout($repo);

    my $build_dir = File::Spec->catdir( $work, $repo->{subdir} );
    chdir($build_dir);

    my $bind = { PERL => $interp };

    # Doesn't work in 5.0.5
    local $ENV{PERL_MM_USE_DEFAULT} = 1;

    my $ok = run_commands(
        $repo->{script},
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
          = $check->($results)
          ? ( $results->{status} ? 'died' : 'passed' )
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
# prove (Test::Harness)
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
        DumpFile( STATUS, $Status );
    }
}
