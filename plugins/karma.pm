use POE::Component::IRC::Common qw/l_irc/;
use DBI;
use DBD::SQLite;

no warnings 'void';

sub {
	my( $said, $pm ) = @_;
	my $body = $said->{body};
	s/^\s+//, s/\s+$// for $body;

	warn "KARMAPLUGIN";
	use Data::Dumper;
	warn Dumper $said;

	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=var/karma.db",
		"",
		"",
		{ RaiseError => 1, PrintError => 0 }
	);

        my $lirc = l_irc($said->{body}) || lc $said->{body};
        $lirc =~ s/^\s*(.*)\s*$/$1/;
	warn "SUBJECT: $lirc";
	my $karma = $dbh->selectrow_arrayref(
		"SELECT sum(operation) FROM karma WHERE subject = ?",
		undef,
		$lirc,
	);

	if( $karma and @$karma) {
		if ($karma->[0])
		{
			print "$body has karma of $karma->[0]";
		}
		else
		{
			print "$body has no karma";
		}
	}
};

__DATA__
karma <nickname>; returns the "karma" value for a user or arbitrary subject. Karma works by appending either ++ or -- to a word to modify its karma.
