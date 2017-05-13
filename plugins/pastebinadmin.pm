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

	my $dbh = $self->{$env . "dbh"} = DBI->connect( "dbi:SQLite:dbname=/var/www/domains/perl.bot/".$env."/pastes.db", "", "", { PrintError => 0, RaiseError => 1 } );

	return $dbh;
}
sub postload {
	my( $self, $pm ) = @_;
	
	delete $self->{wwwdbh}; # UGLY HAX GO.
  delete $self->{devdbh};
	                     # Basically we delete the dbh we cached so we don't fork
                         # with one active
}

sub add_ban_word {
  my ($self, $env, $who, $where, $word) = @_;

  $self->dbh($env)->do("INSERT INTO banned_words (word, who, 'where') VALUES (?, ?, ?)", {}, $word, $who, $where);
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

  if ($command eq 'banword') {
    $self->add_ban_word($env, $said->{sender_raw}, $said->{server}. $said->{channel}, $_) for (@args);
    use Data::Dumper;
    return ("handled", "Added words [".join(', ', @args)."] to ban list");
  } else {
    return ("handled", "Failed to parse [$env, $command, @args]");
  }
}

no warnings 'void';
"Bot::BB3::Plugin::Pastebinadmin";

__DATA__
The pastebinadmin plugin.  Lets operators change options on the https://perlbot.pl/ pastebin.  perlbot: pastebinadmin [--dev] <command> [<args>]. see https://github.com/perlbot/perlbuut-pastebin/wiki/Op-Tools
