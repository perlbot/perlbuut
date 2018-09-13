package Bot::BB3::Plugin::Tell;
use strict;
no warnings 'void';
sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = 'tell';
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;

  
  my ($who, $what);
  
  
  if ($said->{body} =~ /^\s*(.*?)\s+about\s+(.*)$/ ||
      $said->{body} =~ /^\s*(\S*)\s+(.*)$/) {
    ($who, $what) = ($1, $2)
  } else {
    return ("handled", "Tell who about what?");
  }

  my ($success, $result) = runplugin($what, $said, $who, $pm);

  unless ($success) {
    my $result2;
    ($success, $result2) = runplugin("default $what", $said, $who, $pm);

    if ($success) {
      $result = $result2;
    }
  }

  if ($success) {
    return ("handled", "\x00$who: $result");
  } else {
    return ("handled", "Couldn't find anything for $what");
  }
}

sub runplugin {
	my( $cmd_string, $said, $who, $pm) = @_;
	my( $cmd, $body ) = split " ", $cmd_string, 2;
	defined($cmd) or
		return( 0, "Error, cannot parse call to find command name, probably empty call in compose" );
	defined($body) or $body = "";
	
	my $plugin = $pm->get_plugin( $cmd, $said )
		or return( 0, "Compose failed to find a plugin named: $cmd" );

  my $newsaid = {%$said,
    body => $body,
    recommended_args =>  [ split /\s+/, $body ],
    command_match =>  $cmd,
    name =>  $who,
    body_raw =>  $said->{addressed_as}. ": $body",
    sender_raw =>  "$who!~$who\@NONLOCAL",
    by_root => 0,
    by_chan_op => 0,
    ircnname => "~$who",
    host => "NONLOCAL",
    nested => 1,
  };

	local $@;
	my( $status, $results ) = eval { $plugin->command( $newsaid, $pm ) };

	if( $@ ) { return( 0, "Failed to execute plugin: $cmd because $@" ); }

	else { return( 1, $results ) }

	return( 0, "Error, should never reach here" );
}


"Bot::BB3::Plugin::Tell";

__DATA__
Tell other users about things.  tell <who> [about] <what>"
