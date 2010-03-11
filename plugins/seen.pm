package Bot::BB3::Plugin::Seen;
use POE::Component::IRC::Common qw/l_irc/;
use DBD::SQLite;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = "seen";
	$self->{opts} = {
		command => 1,
		handler => 1,
	};

	return $self;
}

sub dbh {
	my( $self ) = @_;

	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = $self->{dbh} = DBI->connect( "dbi:SQLite:dbname=var/seen.db", "", "", { PrintError => 0, RaiseError => 1 } );

	return $dbh;
}
sub postload {
	my( $self, $pm ) = @_;
	

	my $sql = "CREATE TABLE seen (
		seen_id INTEGER PRIMARY KEY AUTOINCREMENT,
		user VARCHAR(25),
		lc_user VARCHAR(25),
		message VARCHAR(250),
		seen_date INTEGER
	);";

	$pm->create_table( $self->dbh, "seen", $sql );

	delete $self->{dbh}; # UGLY HAX GO.
	                     # Basically we delete the dbh we cached so we don't fork
											 # with one active
}

sub command {
	my( $self, $said, $pm ) = @_;
	my( $target ) = @{ $said->{recommended_args} };

	my $seen = $self->dbh->selectrow_arrayref( "SELECT user,message,seen_date FROM seen WHERE lc_user = ?", 
		undef, 
		l_irc( $target )
	);

	if( $seen and @$seen and $seen->[0] ) {

		return( 'handled', "I last saw $seen->[0] saying \"$seen->[1]\" at " . gmtime($seen->[2]) . " Z." );
	}
	else {
		return( 'handled', "I don't think I've seen $target." );
	}
}

sub handle {
	my ( $self, $said, $pm ) = @_;

	my $count = $self->dbh->do( "UPDATE seen SET user = ?, message = ?, seen_date = ? WHERE lc_user = ?", 
		undef,
		$said->{name},
		$said->{body},
		time(),
		l_irc( $said->{name} ),
	);

	if( $count == 0 ) {
		$self->dbh->do( "INSERT INTO seen (user,lc_user,message,seen_date) VALUES ( ?,?,?,? )",
			undef,
			$said->{name},
			l_irc($said->{name}),
			$said->{body},
			time(),
		);
	}

	return;
}

1#"Bot::BB3::Plugin::Seen";

__DATA__
The seen plugin. Attempts to keep track of every user the bot has 'seen'. Use the syntax, seen user; to ask the bot when it last saw the user named 'user'.

