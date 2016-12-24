#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use DBI;
use Text::Metaphone;

my $dbh = DBI->connect(
	"dbi:SQLite:dbname=var/factoids.db",
	"",
	"",
	{ RaiseError => 1, PrintError => 0 }
);

my $fsth = $dbh->prepare('SELECT * FROM factoid;');
my $isth = $dbh->prepare('UPDATE factoid SET metaphone = ? WHERE factoid_id = ?');

$fsth->execute();

while (my $row = $fsth->fetchrow_hashref()) {
    my $orig_sub = $row->{original_subject};

    my $metaphone = Metaphone($orig_sub);
    print "$orig_sub => $metaphone\n";
    $isth->execute($metaphone, $row->{factoid_id});
}
