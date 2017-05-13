package Bot::BB3::Plugin::Allowpaste;
use POE::Component::IRC::Common qw/l_irc/;
use DBD::SQLite;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = "allowpaste";
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub dbh {
	my( $self ) = @_;

	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = $self->{dbh} = DBI->connect( "dbi:SQLite:dbname=var/allowpaste.db", "", "", { PrintError => 0, RaiseError => 1 } );

	return $dbh;
}
sub postload {
	my( $self, $pm ) = @_;
	

	my $sql = "CREATE TABLE allowpaste (
        channel VARCHAR(255) NOT NULL UNIQUE,
        value INTEGER NOT NULL,
        setby VARCHAR(255) NOT NULL,
        set_date INTEGER NOT NULL
	);";

	$pm->create_table( $self->dbh, "allowpaste", $sql );

	delete $self->{dbh}; # UGLY HAX GO.
	                     # Basically we delete the dbh we cached so we don't fork
                         # with one active
}

sub get_status {
    my ($self, $chancon) = @_;

    my $status = $self->dbh->selectrow_hashref('SELECT value FROM allowpaste WHERE channel = ?', {}, $chancon);

    return ($status // {})->{value};
}

sub set_status {
    my ($self, $chancon, $setting, $who) = @_;
   
    if (defined $self->get_status($chancon)) {
        $self->dbh->do('UPDATE allowpaste SET value = ?, setby = ?, set_date = ? WHERE channel = ?', {}, $setting eq 'on' ? 1 : 0, $who, time(), $chancon);
    } else {
        $self->dbh->do('INSERT INTO allowpaste (channel, value, setby, set_date) VALUES (?, ?, ?, ?)', {}, $chancon, $setting eq 'on' ? 1 : 0, $who, time());
    }
}

sub command {
	my( $self, $said, $pm ) = @_;
	my( $cmd ) = join ' ', @{ $said->{recommended_args} };

  my ($global, $set_to);
  if ($cmd =~ /^\s*(?<global>global)?\s*(?<set_to>on|off)?\s*$/i) {
    $global = $+{global} // "channel";
    $set_to = $+{set_to};
  }
  
  my $server_conf = $pm->{bb3}{'Bot::BB3::Roles::IRC'}{bot_confs}{$said->{pci_id}};
  my ($botname, $servername) = @{$server_conf}{qw/botname server/};
  my $channel = $said->{channel};

  my $chanconstruct = "$servername:$botname:$channel";

  $chanconstruct = "GLOBAL" if $global eq 'global';

  if ($set_to && (lc($set_to) eq 'on' || lc($set_to) eq 'off')) {
    $self->set_status($chanconstruct, $set_to, $said->{name});
    return('handled', "This $global has pastebin set [$set_to]"); 
  } else {
    my $status = $self->get_status($chanconstruct)//1 ? 'on' : 'off';
    return('handled', "This $global has pastebin set to [$status] :: $chanconstruct");
  }
}

no warnings 'void';
"Bot::BB3::Plugin::Allowpaste";

__DATA__
The allowpaste plugin.  Lets operators disable pastes being announced in the channel.  allowpaste [global] [on|off] => Tell you the state, or turn it on or off.
See https://github.com/perlbot/perlbuut-pastebin/wiki/Op-Tools for more documentation
