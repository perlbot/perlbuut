use POE::Component::IRC::Common qw/l_irc/;
use DBI;
use DBD::SQLite;

sub {
	my( $said, $pm ) = @_;
	my $body = $said->{body};
	s/^\s+//, s/\s+$// for $body;

	warn "KARMATOPPLUGIN";
	use Data::Dumper;
	warn Dumper $said;

	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=var/karma.db",
		"",
		"",
		{ RaiseError => 1, PrintError => 0 }
	);

        if ($said->{body} =~ /\s*(\d+)(\s*karma)?/)
        {
           my $count = $1;
           my $sth;
           if ($count > 0)
           {
             $sth = $dbh->prepare("SELECT subject, kars FROM (SELECT subject, sum(operation) as kars FROM karma GROUP BY subject) AS karmsub ORDER BY kars ASC LIMIT ?");
           }
           else
           {
             $sth = $dbh->prepare("SELECT subject, kars FROM (SELECT subject, sum(operation) as kars FROM karma GROUP BY subject) AS karmsub ORDER BY kars DESC LIMIT ?");
           }

           $sth->execute(abs $count);

           while (my $row = $sth->fetchrow_arrayref())
           {
              print $row->[0], ": ", $row->[1], "  ";
           }
        }
        else
        {
           print "usage is: top/bottom \d+ karma";
        }
}

__DATA__
karmatop <number>; returns the top or bottom karma for a number of things.
