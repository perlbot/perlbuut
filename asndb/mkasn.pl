#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use DBI;
use Net::CIDR;
use Data::Dumper;

sub fmtip($) {
  my $ip = shift;
  sprintf "%03d.%03d.%03d.%03d", split(/\./, $ip);
}

open(my $tsv, "<", "GeoLite2-ASN-Blocks-IPv4.csv");


my $dbh = DBI->connect("dbi:SQLite:dbname=../var/asn.db", "", "", {RaiseError => 1});

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
  my ($cidr, $asn, $desc) = split /,/, $line, 3;
  my ($range) = Net::CIDR::cidr2range($cidr);
  my ($start, $end) = split('-', $range);
  my $country = "UNK";
#  print Dumper({cidr => $cidr, asn => $asn, range => $range, start => $start, end => $end});
  next if $asn eq 0;
  printf "%s - %s\n", fmtip($start), fmtip($end);
  $insert_sth->execute(fmtip $start, fmtip $end, $asn, $country, $desc);
}
#$dbh->commit();
#$dbh->begin_work();
for my $ip (0..255) {
  my $rv = $dbh->do("DELETE FROM asn WHERE start <= ? AND end >= ?", {}, fmtip "10.$ip.0.0", fmtip "10.$ip.0.0");
  $rv+=$dbh->do("DELETE FROM asn WHERE start <= ? AND end >= ?", {}, fmtip "172.$ip.0.0", fmtip "172.$ip.0.0") if $ip >= 16 || $ip <= 32;
  $rv+=$dbh->do("DELETE FROM asn WHERE start <= ? AND end >= ?", {}, fmtip "192.168.$ip.0", fmtip "192.168.$ip.0");
  print "Removed $rv for $ip\n";
}
$dbh->commit();
