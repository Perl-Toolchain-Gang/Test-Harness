#!/usr/bin/perl 

use strict;
use warnings;
use DBI;
use Cwd qw( realpath getcwd );
use Archive::Any;
use File::Temp qw(tempfile tempdir);
use File::Copy;
use File::Spec::Functions qw(splitpath);
use File::Find::Rule;

# XXX adjust to taste
my $verbose     = 0;
my $MAX_SECONDS = 300;
my $MAKE        = 'make';

my $MINICPANRC = glob '~/.minicpanrc';

# XXX should point to your minicpan distributions
my $DISTRIBUTIONS
  = -f $MINICPANRC
  ? File::Spec->catdir( _mini_rc($MINICPANRC)->{local}, 'authors', 'id' )
  : '/Users/ovid/code/minicpan/authors/id/';

#my $DISTRIBUTIONS = '/Users/ovid/code/minicpan/authors/id/O/OV/OVID';

# XXX should point to the harnesses you want to test against
my @harnesses = map realpath($_), qw(
  reference/Test-Harness-2.64/lib
  lib
);

# XXX change anything below this at your peril
sub _print (@) {
    print @_ if $verbose;
}

_print "Searching for distributions in $DISTRIBUTIONS\n";
my @files = File::Find::Rule->file->name('*.tar.gz')->in($DISTRIBUTIONS);
my $dbh   = dbh();
foreach my $harness (@harnesses) {
    my $version_id = get_version_id($harness);
    foreach my $file (@files) {

        #next unless $file =~ /AsHash/;    # only test the easiest one
        test_distribution( $harness, $version_id, $file );
    }
}

sub test_distribution {
    my ( $harness, $version_id, $file ) = @_;
    my $distribution = extract_archive($file);
    _print "Found distribution at $distribution\n";
    build( $harness, $version_id, $distribution );
}

sub build {
    my ( $harness, $harness_id, $distribution ) = @_;
    my $cwd = getcwd;
    chdir $distribution;
    my $command
      = -f 'NotBuild.PL' ? "perl -I$harness NotBuild.PL && ./Build test"
      : -f 'Build.PL'    ? "perl -I$harness Build.PL && ./Build test"
      : -f 'Makefile.PL' ? "perl -I$harness Makefile.PL && $MAKE test"
      :                    warn "Don't know how to build $distribution";
    return unless $command;
    my @results;
    eval {
        local $SIG{ALRM} = sub {
            die "$distribution timed out at $MAX_SECONDS\n";
        };
        alarm $MAX_SECONDS;
        chomp( @results = qx($command) );
        alarm 0;
    };
    my $passfail;
    if ( my $error = $@ ) {
        _print $error;
        $passfail = "Error:  $error";
    }
    elsif ( !@results ) {
        _print "No results found for $distribution";
        $passfail = 'No results';
    }
    else {
        $passfail
          = ( grep {/All tests successful/} @results )
          ? 'PASS'
          : 'FAIL';
    }
    my ( undef, undef, $dist ) = splitpath($distribution);
    my $package_id = get_package_id($dist);
    _print "$dist ($package_id): $passfail\n";
    save_result( $harness_id, $package_id, $passfail );
    chdir $cwd;
}

sub save_result {
    my ( $harness_id, $package_id, $result ) = @_;
    my $dbh     = dbh();
    my $results = <<'    END_SQL';
    SELECT 1
    FROM   test_runs
    WHERE  harness_id = ?
      AND  package_id = ?
    END_SQL
    my $sql;
    if (@{  $dbh->selectall_arrayref(
                $results, undef, $harness_id,
                $package_id
            )
        }
      )
    {
        $sql = <<'        END_SQL';
        UPDATE test_runs
        SET    result     = ?
        WHERE  harness_id = ?
          AND  package_id = ?
        END_SQL
    }
    else {
        $sql = <<'        END_SQL';
        INSERT INTO test_runs
            ( result, harness_id, package_id )
        VALUES ( ?, ?, ? )
        END_SQL
    }
    $dbh->do( $sql, undef, $result, $harness_id, $package_id );
}

sub get_package_id {
    my $package = shift;
    my $dbh     = dbh();

    # this is a bit wonky because I don't know if $dbh->last_insert_id() and
    # SQLite are both able to handle forked processes
    my $id = _get_package_id($package);
    $dbh->do( 'INSERT INTO packages (name) VALUES (?)', undef, $package );
    return _get_package_id($package);
}

sub _get_package_id {
    my $package = shift;
    my $id      = $dbh->selectcol_arrayref(
        'SELECT id FROM packages WHERE name = ?',
        undef, $package
    );
    return $id->[0] if $id;
    return;
}

sub get_version_id {
    my $harness = shift;
    my $version = qx(
      perl -I$harness -MTest::Harness -e 'print Test::Harness->VERSION'
    );
    my $dbh = dbh();

    # this is a bit wonky because I don't know if $dbh->last_insert_id() and
    # SQLite are both able to handle forked processes
    my $id = _get_version_id($version);
    $dbh->do( 'INSERT INTO harnesses (version) VALUES (?)', undef, $version );
    return _get_version_id($version);
}

sub _get_version_id {
    my $version = shift;
    my $id      = $dbh->selectcol_arrayref(
        'SELECT id FROM harnesses WHERE version = ?',
        undef, $version
    );
    return $id->[0] if $id;
    return;
}

sub extract_archive {
    my $file = shift;
    my ( undef, undef, $dist ) = splitpath($file);
    my $tempfile = File::Temp->new(
        SUFFIX => '.tar.gz',
        UNLINK => 1,
    );
    my $tempdir = tempdir( CLEANUP => 1 );

    copy( $file, "$tempfile" )
      or warn "Could not copy ($file) to ($tempfile): $!";

    my $archive = Archive::Any->new("$tempfile");
    foreach my $is_bad (qw(is_naughty is_impolite)) {
        if ( $archive->$is_bad ) {
            warn "Archive $is_bad.  Skipping\n";
            return;
        }
    }
    _print "Extracting $dist to $tempdir\n";
    $archive->extract($tempdir);
    my @distribution = File::Find::Rule->directory->maxdepth(1)->in($tempdir);
    return $distribution[-1];
}

sub _mini_rc {
    my $file   = shift;
    my $config = {};
    open my $fh, '<', $file or die "Can't read $file ($!)\n";
    while ( defined( my $line = <$fh> ) ) {
        chomp $line;
        next if $line =~ /^\s*?(?:#.*)?$/;
        if ( $line =~ /^(\S+):\s+(.+)$/ ) {
            $config->{$1} = $2;
        }
        else {
            warn "Unrecognised line: $line\n";
        }
    }
    return $config;
}

{
    my $dbh;

    sub dbh {

        #`rm harness_runs.db`;
        unless ($dbh) {
            $dbh = DBI->connect(
                "dbi:SQLite:dbname=harness_runs.db",
                "", "", { RaiseError => 1 },
            ) or die $DBI::errstr;
            my $tables = $dbh->selectall_arrayref(
                'select tbl_name from sqlite_master');
            unless (@$tables) {
                local $/ = ';';
                while ( defined( my $create_table = <DATA> ) ) {
                    print $create_table;
                    $dbh->do($create_table);
                }
            }
        }
        return $dbh;
    }
}

__DATA__
CREATE TABLE harnesses (
    id      INTEGER PRIMARY KEY,
    version TEXT
);

CREATE TABLE packages (
    id   INTEGER PRIMARY KEY,
    name TEXT
);

CREATE TABLE test_runs (
    id         INTEGER PRIMARY KEY,
    harness_id INTEGER,
    package_id INTEGER,
    result     TEXT 
);

CREATE VIEW mismatches AS SELECT p.name, h.version, t1.result, t2.result
FROM   test_runs t1, test_runs t2
INNER JOIN harnesses h ON t1.harness_id = h.id
INNER JOIN packages p  ON  t1.package_id = p.id
WHERE t2.harness_id != t1.harness_id
  AND t2.package_id  = t1.package_id
  AND t2.result     != t1.result;
