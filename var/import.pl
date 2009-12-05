#!/usr/bin/perl

use Data::Dumper;
use DBI;

use strict;
use warnings;

use Text::Soundex qw/soundex/; #didn't know buu did this!

sub _clean_subject {
        my( $subject ) = @_;

        $subject =~ s/^\s+//;
        $subject =~ s/\s+$//;
        $subject =~ s/\s+/ /g;
#        $subject =~ s/[^\w\s]//g; #comment out to fix punct in factoids
        $subject = lc $subject;

        return $subject;
}

my $dbhnew = DBI->connect(
                "dbi:SQLite:dbname=factoids.db",
                "",
                "",
                { RaiseError => 1, PrintError => 0 }
        );

my $dbhold = DBI->connect("dbi:SQLite:dbname=../perlbotstuff/data/facts.db","","", { RaiseError => 1, PrintError => 0 });

my @facts;

my $sth = $dbhold->prepare("SELECT * FROM facts;");

$sth->execute();

while (my $row =$sth->fetchrow_arrayref())
{
  print Dumper($row);
  push @facts, {subject => $row->[0], predicate => $row->[1], copula => 'is', author => 'perlbot', original_subject => _clean_subject($row->[0]), modified_time => time, soundex => soundex($row->[0])}
}

for (@facts)
{
$dbhnew->do( "INSERT INTO factoid 
           (original_subject,subject,copula,predicate,author,modified_time,soundex,compose_macro)
           VALUES (?,?,?,?,?,?,?,?)",
	   undef,	   
	   @$_{qw(original_subject subject copula predicate author modified_time soundex)},
           0,
        );
}


#CREATE TABLE factoid (
#		factoid_id INTEGER PRIMARY KEY AUTOINCREMENT,
#		original_subject VARCHAR(100),
#		subject VARCHAR(100),
#		copula VARCHAR(25),
#		predicate TEXT,
#		author VARCHAR(100),
#		modified_time INTEGER,
#		soundex VARCHAR(4),
#		compose_macro CHAR(1) DEFAULT '0'
