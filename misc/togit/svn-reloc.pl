#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Data::Dumper;
use List::Util qw( min );
use Storable qw( dclone );

{
  my $fix_tags = sub {
    my ( $proj, $type, $name ) = @_;
    return "$type/$proj-$name/$proj";
  };

  relocate(
    *STDIN => sub {
      my $name = shift;

      # General relocations
      $name =~ s{^trunk\b}{trunk/Test-Harness};
      $name =~ s{^(tags|branches)/([^/]+)}
                  {$1/Test-Harness-$2/Test-Harness};
      $name =~ s{^([^/]+)/trunk\b}{trunk/$1};
      $name =~ s{^([^/]+)/(tags|branches)/([^/]+)}
                  {$fix_tags->($1,$2,$3)}e;

      # tap-tests has no trunk/tags/branches
      $name =~ s{^tap-tests}{trunk/tap-tests};
      return $name;
    },
    sub {
      my $rec = shift;

      # Adjust copies of trunk -> tag|branches/foo so that the whole
      # tree is copied rather than just the individual subproject
      my $kind   = $rec->{'Node-kind'}   // '';
      my $action = $rec->{'Node-action'} // '';
      my $path   = $rec->{'Node-path'}   // '';
      my $cfpath = $rec->{'Node-copyfrom-path'};

      if ( $action eq 'add'
        && $kind eq 'dir'
        && defined $cfpath
        && $path =~ m{^(branches|tags)/([^/]+)/([^/]+)$} ) {
        my ( $type, $name, $proj ) = ( $1, $2, $3 );
        $rec->{'Node-copyfrom-path'} =~ s{^trunk/\Q$proj\E$}{trunk};
        $rec->{'Node-path'} = "$type/$name";
      }
      elsif ( $action eq 'delete'
        && $path =~ m{^(branches|tags)/([^/]+)/([^/]+)$} ) {
        my ( $type, $name, $proj ) = ( $1, $2, $3 );
        $rec->{'Node-path'} = "$type/$name";
      }
    },
  );
}

sub dir_name {
  return unless ( my $path = shift ) =~ s:/[^/]+$::;
  return $path;
}

sub relocate {
  my ( $fh, $mapper, $munger ) = @_;

  my %dirs  = ();      # dirs that have been created
  my %rdirs = ();
  my $lrev  = undef;

  my $mkdir;
  $mkdir = sub {
    my $name = shift;
    return unless defined $name && length $name;
    return if $dirs{$name};
    $mkdir->( dir_name( $name ) );
    print
     "Node-path: $name\n",
     "Node-kind: dir\n",
     "Node-action: add\n",
     "Prop-content-length: 10\n",
     "Content-length: 10\n",
     "\n",
     "PROPS-END\n",
     "\n",
     "\n";
    $dirs{$name}++;
  };

  my $cpdir = sub {
    my ( $path, $cfrev, $cfpath ) = @_;
    my $cfdirs = $rdirs{$cfrev}
     or die "No rev: $cfrev to copy $cfpath from\n";
    print STDERR "Copy $path from -r$cfrev $cfpath\n";
    $path   = "$path/"   if length $cfpath == 0;
    $cfpath = "$cfpath/" if length $path == 0;
    for ( grep { /^\Q$cfpath/ } keys %$cfdirs ) {
      print STDERR "  $_ -> ";
      s/^\Q$cfpath/$path/;
      print STDERR "$_\n";
      $dirs{$_}++;
    }
  };

  my $rmdir = sub {
    my $path = shift;
    my @rm = grep { /^\Q$path/ } keys %dirs;
    delete @dirs{@rm};
  };

  with_svn(
    $fh => sub {
      my $rec  = shift;
      my %need = ();

      if ( my $pre = $rec->{_pre} ) {
        print $pre;
        return;
      }

      if ( defined( my $rev = $rec->{'Revision-number'} ) ) {
        print STDERR "Revsion $rev\n";
        $rdirs{$lrev} = dclone \%dirs if defined $lrev;
        $lrev = $rev;
      }

      for my $k ( qw( Node-path Node-copyfrom-path ) ) {
        if ( exists $rec->{$k} ) {
          my $nd = dir_name( $rec->{$k} = $mapper->( $rec->{$k} ) );
          $need{$nd}++ if defined $nd;
        }
      }

      $munger->( $rec ) if $munger;

      my $action = $rec->{'Node-action'} || '';
      if ( ( $rec->{'Node-kind'} || '' ) eq 'dir' ) {
        my $path = $rec->{'Node-path'};
        if ( $action eq 'add' ) {
          my $up = dir_name( $path );
          $mkdir->( $up ) if defined $up;
          my $cfrev  = $rec->{'Node-copyfrom-rev'};
          my $cfpath = $rec->{'Node-copyfrom-path'};
          if ( defined $cfpath ) {
            $cpdir->( $path, defined $cfrev ? $cfrev : $lrev, $cfpath );
          }
          else {
            $dirs{$path}++;
          }
        }
        elsif ( $action eq 'delete' ) {
          $rmdir->( $path );
        }
      }
      elsif ( $action ne 'delete' ) {
        $mkdir->( $_ ) for sort keys %need;
      }

      print_rec( $rec );
    }
  );
}

sub print_rec {
  my %rec = %{ $_[0] };

  my $body = delete $rec{_body};
  delete $rec{_hdr};

  for my $k ( @{ delete $rec{_order} || [] }, sort keys %rec ) {
    print "$k: ", delete $rec{$k}, "\n" if exists $rec{$k};
  }

  print "\n";
  print $body if defined $body;
  print "\n";
}

sub with_svn {
  my ( $fh, $cb ) = @_;
  my @pre    = ();
  my $hdr    = {};
  my $in_pre = 1;
  my $ln     = 1;

  my $cksize = 2048;
  my $buffer = '';

  my $fillbuf = sub {
    my $want   = shift;
    my $toread = $cksize;
    if ( defined $want ) {
      my $need = $want - length $buffer;
      $toread = int( ( $need + $cksize - 1 ) / $cksize ) * $cksize
       if $need > $toread;
    }
    read $fh, my ( $chunk ), $toread;
    $buffer .= $chunk;
  };

  $fillbuf->( 2048 );
  die "Can't find first revision\n"
   unless $buffer =~ s/(.*)^(Revision-number)/$2/ms;
  my $pre = $1;
  my $rec = ();

  $cb->( { _pre => $pre }, 1 );

  while () {
    last if eof $fh && length $buffer == 0;
    if ( $buffer =~ s/^((.+?): *(.*)\n)// ) {
      $rec->{_hdr} .= $1;
      $rec->{$2} = $3;
      push @{ $rec->{_order} }, $2;
    }
    elsif ( $buffer =~ s/^(\n)// ) {
      $rec->{_hdr} .= $1;
      if ( my $cl = $rec->{'Content-length'} ) {
        $fillbuf->( $cl );
        $rec->{_body} = substr $buffer, 0, $cl;
        $buffer = substr $buffer, $cl;
      }
      $fillbuf->( 20 );
      $buffer =~ s/^\n+//;    # Extra blanks after content
      $cb->( $rec, 2 );
      $rec = {};
    }
    elsif ( length $buffer >= 2048 ) {
      die "Plenty of data but no match!\n";
    }
    else {
      $fillbuf->();
    }
  }
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

