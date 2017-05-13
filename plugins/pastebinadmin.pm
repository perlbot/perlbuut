package Bot::BB3::Plugin::Pastebinadmin;
use POE::Component::IRC::Common qw/l_irc/;
use DBD::SQLite;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = "pastebinadmin";
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub dbh {
	my( $self, $env ) = @_;

	if( $self->{$env . "dbh"} and $self->{$env . "dbh"}->ping ) {
		return $self->{$env . "dbh"};
	}
  
  if ($env =~ /^www|dev$/) {
    $self->{$env . "dbh"} = DBI->connect( "dbi:SQLite:dbname=/var/www/domains/perl.bot/".$env."/pastes.db", "", "", { PrintError => 0, RaiseError => 1 } );
  } elsif ($env eq 'asn') {
    $self->{$env . "dbh"} = DBI->connect( "dbi:SQLite:dbname=var/asn.db", "", "", { PrintError => 0, RaiseError => 1 } );
  }

	return $self->{$env."dbh"};
}
sub postload {
	my( $self, $pm ) = @_;
	
	delete $self->{wwwdbh}; # UGLY HAX GO.
  delete $self->{devdbh};
  delete $self->{asndbh};
	                     # Basically we delete the dbh we cached so we don't fork
                         # with one active
}

sub add_ban_word {
  my ($self, $env, $who, $where, $word) = @_;

  $self->dbh($env)->do("INSERT INTO banned_words (word, who, 'where') VALUES (?, ?, ?)", {}, $word, $who, $where);
}

sub get_ip_for_paste {
  my ($self, $env, $id) = @_;

  my ($ip) = @{$self->dbh($env)->selectrow_arrayref("SELECT ip FROM posts p JOIN slugs s ON s.post_id = p.id WHERE s.slug = ?", {}, $id) || ['0.0.0.0']};

  return sprintf("%03d.%03d.%03d.%03d", split(/\./,$ip));
}

sub get_asn_for_paste {
  my ($self, $env, $id) = @_;

  my $ip = $self->get_ip_for_paste($env, $id);

  my ($asn) = @{$self->dbh('asn')->selectrow_arrayref("SELECT asn FROM asn WHERE ? >= start AND ? <= end", {}, $ip, $ip) || []}[0];
  return $asn;
}

sub ban_user_paste {
  my ($self, $env, $id, $who, $where) = @_;

  my $ip = $self->get_ip_for_paste($env, $id);

  if ($ip) {
    $self->dbh($env)->do("INSERT INTO banned_ips (ip, who, 'where') VALUES (?, ?, ?);", {}, $ip, $who, $where);
    return "USER WAS BANNED FOR THIS POST";
  } else {
    return "Failed to find IP for paste in db";
  }
}

sub ban_asn_paste {
  my ($self, $env, $id, $who, $where) = @_;

  my $asn = $self->get_asn_for_paste($env, $id);

  if ($asn) {
    $self->dbh($env)->do("INSERT INTO banned_asns (asn, who, 'where') VALUES (?, ?, ?);", {}, $asn, $who, $where);
    return "ISP WAS BANNED FOR THIS POST";
  } else {
    return "Failed to find ISP for paste in db. yell at simcop2387";
  }
}

sub command {
	my( $self, $said, $pm ) = @_;
	my( $cmd ) = join ' ', @{ $said->{recommended_args} };

  my ($env, $command, @args);
  if ($cmd =~ /^\s*(?<dev>--dev)?\s*(?<command>\S+)\s*(?<args>.*?)\s*$/i) {
    $env = $+{dev} ? "dev" : "www";
    $command = $+{command};
    @args = split ' ', $+{args};
  }

  my $where = $said->{server} . $said->{channel};
  my $who = $said->{sender_raw};

  if ($command eq 'banword') {
    $self->add_ban_word($env, $who, $where, $_) for (@args);
    use Data::Dumper;
    return ("handled", "Added words [".join(', ', @args)."] to ban list");
  } elsif ($command eq 'banuser') {
    my $paste = $args[0];
    
    if (my ($id) = ($paste =~ m{^(?:(?:https?://(?:[a-z\.]+)?perlbot.pl/p(?:astebin)?/([^/]{6,})/?)|([^/]+))$}g)) {
      my $response = $self->ban_user_paste($env, $id, $who, $where);
      return ("handled", $response);
    } else {
      return ("handled", "didn't find an id");
    }
  } elsif ($command eq 'banasn') {
    my $paste = $args[0];
    
    if (my ($id) = ($paste =~ m{^(?:(?:https?://(?:[a-z\.]+)?perlbot.pl/p(?:astebin)?/([^/]{6,})/?)|([^/]+))$}g)) {
      my $response = $self->ban_asn_paste($env, $id, $who, $where);
      return ("handled", $response);
    } else {
      return ("handled", "didn't find an id");
    }

###    $self->ban_user()
  } else {
    return ("handled", "Failed to parse [$env, $command, @args]");
  }
}

no warnings 'void';
"Bot::BB3::Plugin::Pastebinadmin";

__DATA__
The pastebinadmin plugin.  Lets operators change options on the https://perlbot.pl/ pastebin.  perlbot: pastebinadmin [--dev] <command> [<args>]. see https://github.com/perlbot/perlbuut-pastebin/wiki/Op-Tools
