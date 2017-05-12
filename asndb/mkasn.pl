#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use DBI;

sub fmtip($) {
  my $ip = shift;
  sprintf "%03d.%03d.%03d.%03d", split(/\./, $ip);
}

open(my $tsv, "<", "ip2asn-v4.tsv");

my $dbh = DBI->connect("dbi:SQLite:dbname=asn.db", "", "", {RaiseError => 1});

$dbh->do("DROP TABLE IF EXISTS asn;");
$dbh->do(q{CREATE TABLE asn (
  start varchar(15) NOT NULL,
  end   varchar(15) NOT NULL,
  asn   INTEGER NOT NULL,
  country TEXT,
  desc TEXT
);
CREATE INDEX asn_start ON asn (start);
CREATE INDEX asn_end ON asn (end);
CREATE INDEX ON asn_asn ON asn (asn);});

$dbh->begin_work;
my $insert_sth = $dbh->prepare("INSERT INTO asn (start, end, asn, country, desc) VALUES (?, ?, ?, ?, ?);");

while (my $line = <$tsv>) {
  chomp $line;
  my ($start, $end, $asn, $country, $desc) = split /\t/, $line;

  printf "%s - %s\n", fmtip($start), fmtip($end);
  $insert_sth->execute(fmtip $start, fmtip $end, $asn, $country, $desc);
}
$dbh->commit();
