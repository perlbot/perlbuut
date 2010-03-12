package Bot::BB3::Plugin::Karma_Modify;
use POE::Component::IRC::Common qw/l_irc/;
use DBI;
use DBD::SQLite;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = "karma_modify"; # This shouldn't be necessary
	$self->{opts}->{handler} = 1;

	return $self;
}

sub dbh { 
	my( $self ) = @_;
	
	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = $self->{dbh} = DBI->connect(
		"dbi:SQLite:dbname=var/karma.db",
		"",
		"",
		{ RaiseError => 1, PrintError => 0 }
	);

	return $dbh;
}

sub postload {
	my( $self, $pm ) = @_;


	my $sql = "CREATE TABLE karma (
		karma_id INTEGER PRIMARY KEY AUTOINCREMENT,
		subject VARCHAR(250),
		operation TINYINT,
		author VARCHAR(32),
		modified_time INTEGER
	)"; # Stupid lack of timestamp fields

	$pm->create_table( $self->dbh, "karma", $sql );

	delete $self->{dbh}; # UGLY HAX GO.
	                     # Basically we delete the dbh we cached so we don't fork
											 # with one active

}

sub handle {
	my( $self, $said, $pm ) = @_;
	my $body = $said->{body};

	if( $body =~ /\(([^\)]+)\)(\+\+|--)/ or $body =~ /([\w\[\]\\`_^{|}-]+)(\+\+|--)/ ) {
		my( $subject, $op ) = ($1,$2);
		if( $op eq '--' ) { $op = -1 } elsif( $op eq '++' ) { $op = 1 }
		my $lirc = l_irc($subject) || lc $subject;

		$self->dbh->do( "INSERT INTO karma (subject,operation,author,modified_time) VALUES (?,?,?,?)",
			undef,
			$lirc,
			$op,
			$said->{name},
			scalar time,
		);
	}

	return;
}
no warnings 'void';
"Bot::BB3::Plugin::Karma_Modify";
