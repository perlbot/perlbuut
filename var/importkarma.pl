#!/usr/bin/perl

use Data::Dumper;
use DBI;

use strict;
use warnings;

use Text::Soundex qw/soundex/; #didn't know buu did this!
use POE::Component::IRC::Common qw(l_irc);

my $dbhnew = DBI->connect(
                "dbi:SQLite:dbname=karma.db",
                "",
                "",
                { RaiseError => 1, PrintError => 0 }
        );

my $dbhold = DBI->connect("dbi:SQLite:dbname=../perlbotstuff/data/karma.db","","", { RaiseError => 1, PrintError => 0 });

my @facts;

my $sth = $dbhold->prepare("SELECT * FROM karma;");

$sth->execute();

while (my $row =$sth->fetchrow_arrayref())
{
  print Dumper($row);
  push @facts, {subject => $row->[0], operation=>$row->[1], author=>'perlbot', modified_time=>time}
}

#CREATE TABLE karma (
#                karma_id INTEGER PRIMARY KEY AUTOINCREMENT,
#                subject VARCHAR(250),
#                operation TINYINT,
#                author VARCHAR(32),
#                modified_time INTEGER
#        )"; # Stupid lack of timestamp fields


for (@facts)
{
my $lirc = l_irc($_->{subject}) || lc $_->{subject};
$dbhnew->do( "INSERT INTO karma 
           (subject,operation,author,modified_time)
           VALUES (?,?,?,?)",
	   undef,	   
	   $lirc, @$_{qw(operation author modified_time)},
        );
}


