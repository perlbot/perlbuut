use DBI;

sub {
	my( $said, $pm ) = @_;

	my $dbh = DBI->connect("dbi:SQLite:dbname=var/hosts.db");

	my $recs = $dbh->selectall_arrayref( "SELECT * FROM hosts where host = ?", {Slice=>{}}, $said->{body} );

	print "$said->{body}: ", join ", ", map $_->{nick}, @$recs;
}

__DATA__
host_lookup <hostname>. Returns all of the nicks this bot has seen using the host name you specify.
