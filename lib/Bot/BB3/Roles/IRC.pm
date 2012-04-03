package Bot::BB3::Roles::IRC;

use Bot::BB3::Logger;

use POE;
use POE::Session;
use POE::Wheel::Run;
use POE::Filter::Reference;
use POE::Component::IRC::Common qw/parse_user l_irc/;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::AutoJoin;
use POE::Component::IRC::Plugin::Connector;
use POE::Component::IRC::Plugin::NickReclaim;
use Memoize qw/memoize/;
use Data::Dumper;
use Socket;
use utf8;
use strict;

sub new {
	my( $class, $conf, $plugin_manager ) = @_;

	my $self = bless { conf => $conf, pm => $plugin_manager }, $class;

	my $bots = $self->{conf}->{bot};

	warn Dumper $bots;

	for( @$bots ) {
	warn "Spawning Bot: ", Dumper $_;

	# Blah blah evil
	my $ip = `/sbin/ifconfig | perl -nle' if( /inet addr:(\\d+\\.\\d+\\.\\d+\\.\\d+)/ ) { print \$1; exit }'`;
	# This is to fix a bug with dcc not recognizing our ip..

		my $poco_irc = POE::Component::IRC::State->spawn( 
				nick     => $_->{nick} || $_->{botname},
				username => $_->{username} || $_->{nick} || $_->{botname},
				$_->{password} ? (password => $_->{password}) : (),
			server   => $_->{server},
			port     => $_->{port} || 6667,
			ircname  => $_->{ircname} || $_->{nick} || $_->{botname},
		);

		# Fixes a bug where our remote IP was being sent as 0.0.0.0
		# TODO remove obviously, but maybe add a configuration option to do this.
		# set to 'dynamic' or a host/ip name.
		$poco_irc->{dcc}->nataddr($ip); #Hideously violate encapsulation because I think we need to..

		$poco_irc->plugin_add( 
			AutoJoin => POE::Component::IRC::Plugin::AutoJoin->new( 
				Channels => $_->{channel}
			)
		);
		$poco_irc->plugin_add( Connector => POE::Component::IRC::Plugin::Connector->new );
		$poco_irc->plugin_add( Reclaim   => POE::Component::IRC::Plugin::NickReclaim->new( poll => 120 ) );

		my $pci_id = $poco_irc->session_id;
		$self->{bot_confs}->{ $pci_id } = $_;
		$self->{irc_components}->{ $pci_id } = $poco_irc;
		$self->_build_ignore_hash( $pci_id, $_ );
	}

	$self->{session} = POE::Session->create( 
		object_states => [
			$self => [ qw/ 
				_start

				irc_001
				irc_public
				irc_ctcp_action
				irc_join
				irc_msg
				irc_registered
				irc_474
				irc_dcc_request
				irc_dcc_start
				irc_dcc_chat
				irc_ctcp_chat

				plugin_output

				handle_special_commands
				external_message

				clear_dynamic_ignore
				channel_list
				stop_talking
				start_talking

				comfuckpong
				/
			]
		],
	);

	return $self;
}

sub _build_ignore_hash {
	my( $self, $pci_id, $pci_conf ) = @_;

	for( @{ $pci_conf->{ignore} } ) {
		$self->{bot_ignores}->{$pci_id}->{l_irc $_} = $pci_id;
	}
}

#------------------------------------------------------------------------------
# PUBLIC METHODS
#------------------------------------------------------------------------------
sub comfuckpong
{
  my ($sender, $kernel, $heap) = @_[SENDER, KERNEL, HEAP];

  my $d = $heap->{irc}->server_name();
  $heap->{irc}->yield( quote => "PONG $d\n");
  $kernel->delay_add(comfuckpong => 50);
}

sub get_bot_conf {
	my( $self, $poco_irc ) = @_;
	my $id = ( ref $poco_irc ) ? $poco_irc->session_id : $poco_irc;

	return $self->{bot_confs}->{ $id };
}

sub get_aliases {
	my( $self, $pci ) = @_;
	my $conf = $self->get_bot_conf( $pci );

	my @alias_return;

	my $aliases = $conf->{alias};
	if( not ref $aliases ) { $aliases = [ $aliases ]; }

	my $aliase_res = $conf->{alias_re};
	if( not ref $aliase_res ) { $aliase_res = [ $aliase_res ] }


	return [ grep defined, @$aliase_res, map "\Q$_", grep defined, @$aliases ];
	
}
memoize( 'get_aliases' );

sub get_component {
	my( $self, $pci_id ) = @_;

	return $self->{irc_components}->{ $pci_id };
}

sub is_ignored {
	my( $self, $said ) = @_;
	my $lc_nick = l_irc $said->{name};
	my $lc_body = l_irc $said->{body};

	if( exists $self->{bot_ignores}->{$said->{pci_id}}->{$lc_nick} ) { 
		return 1;
	}

	my $msg_queue = $self->{dynamic_ignores}->{$said->{pci_id}}->{$lc_nick} ||= [];

	push @$msg_queue, $lc_body;
	$poe_kernel->delay_set( clear_dynamic_ignore => 10, $said->{pci_id}, $lc_nick );

	my $match_count;
	for( @$msg_queue ) {
		if( $_ eq $lc_body ) {
			if( ++$match_count > 4 ) {
				return 1;
			}
		}
	}

	return;
}

sub dispatch_said {
	my( $self, $said ) = @_;

	use Data::Dumper;
	warn "DISPATCH_SAID $said->{pci_id} = $said->{channel}\n";
	warn Dumper $self->{squelched_channels};

	if( $self->{squelched_channels}->{$said->{pci_id}}->{lc $said->{channel}}
		and not $said->{addressed}
	) {
		return;
	}


	warn "Sending on execute_said\n";
	$self->{pm}->yield( execute_said => $said );
}

#------------------------------------------------------------------------------
# POE STATES
#------------------------------------------------------------------------------
sub _start {
	my( $self, $kernel, $session ) = @_[OBJECT,KERNEL,SESSION];

	$kernel->signal( $kernel, 'POCOIRC_REGISTER', $session->ID, 'all' );

	$kernel->alias_set( __PACKAGE__ );
}

sub stop_talking {
	my( $self, $poco_id, $channel ) = @_[OBJECT,ARG0,ARG1];

	warn "RECEIVED STOP TALKING: $poco_id, $channel\n";
	$self->{squelched_channels}->{$poco_id}->{lc $channel} = 1;
}

sub start_talking {
	my( $self, $poco_id, $channel ) = @_[OBJECT,ARG0,ARG1];

	delete $self->{squelched_channels}->{$poco_id}->{lc $channel};
}

sub irc_registered {
	my( $self, $sender, $kernel, $pci ) = @_[OBJECT,SENDER,KERNEL,ARG0];

	$pci->yield( connect => {} );
}

sub _said {
	my( $self, $sender, $kernel ) = @_[OBJECT,SENDER,KERNEL];
	my $caller = ((caller(1))[3]); 
		$caller =~ /:([^:]+)$/ and $caller = $1;

	my $pci = $self->get_component($sender->ID);
	my $said = {};

	$said->{server} = $pci->server_name;
	$said->{my_name} = $pci->nick_name;
	$said->{pci_id} = $pci->session_id;

	#--------------------------
	# Method Specific Logic
	#--------------------------
	if( $caller eq 'irc_public' ) {
		$said->{ sender_raw } = $_[ARG0];
		$said->{ body_raw } = $_[ARG2];
		$said->{ channel } = $_[ARG1]->[0];
	}
	elsif( $caller eq 'irc_msg' ) {
		$said->{ sender_raw } = $_[ARG0];
		$said->{ body_raw } = $_[ARG2];
		$said->{ channel } = '*irc_msg';
		$said->{ addressed } = 1;
	}
	elsif( $caller eq 'irc_ctcp_action' ) {
		$said->{ sender_raw } = $_[ARG0];
		$said->{ body_raw } = $_[ARG2];
		$said->{ channel } = $_[ARG1]->[0];
	}
	elsif( $caller eq 'irc_dcc_chat' ) { 
		$said->{ body_raw } = $_[ARG3];
		$said->{ channel } = '*dcc_chat';
		$said->{ addressed } = 1;

		# We only get the IP Address from the dcc_chat events so we need to try to
		# turn it back in to a hostname, since that's usually what we have here
		# Presumably the irc server is normally doing a rdns lookup anyway
		# which is what we're trying to emulate here.
		# In this case we pack the IP address and an arbitrary port (80) in to a
		# magically opaque struct and then unpack it back in to .. something
		# using sockaddr_in and then we can get the hostname from gethostbyaddr
		my $addr_struct = pack_sockaddr_in( 80, inet_aton($_[ARG4]) );
		my($port,$iaddr)=sockaddr_in($addr_struct);

		$said->{ host } = gethostbyaddr($iaddr,AF_INET());
		# Recreate the sender_raw in the form of nick!nick@hostname so our root check
		# later on will work properly
		$said->{ sender_raw } = $_[ARG1] . '!' . $_[ARG1] . '@' . $said->{host};
	}
	else {
		die "ERROR, _said called by unknown caller: $caller";
	}
	#--------------------------

	my @user_info = parse_user( $said->{ sender_raw } );
	for( qw/name ircname host/ ) {
		if( not defined $user_info[0] ) {
			last;
		}

		$said->{$_} = shift @user_info;
	}

	#--------------------------
	# Check for our own name
	#--------------------------
	$said->{body} = $said->{body_raw};

	if( $said->{my_name} ) { #TODO verify that we need this if check.
		my $body = $said->{body_raw};

		my $aliases = $self->get_aliases( $pci );
		my $name_re = "(?:" . join( "|", map "(?:$_)", $said->{my_name}, @$aliases ) . ")"; 

		if( $body =~ s/^\s*($name_re)\b\s*[;:, ]\s*// ) {
			$said->{body} = $body;
			$said->{addressed} = 1;
			$said->{addressed_as} = $1;
		}
		elsif ($body =~ s/\s*\b($name_re)\s*$//)
                {
                        $said->{body} = $body;
                        $said->{addressed} = 1;
                        $said->{addressed_as} = $1;
                        $said->{backdressed} = 1;
                }
	}

	#--------------------------
        # Check for forwarded message
        #--------------------------

#        if ($said->{addressed} && $said->{body} =~ s/\s*>\s*\b([^\s>]+)\s*$//)
#        {
           #we have a forwarded message
#           $said->{forwarding} = $1;
#        }

	#--------------------------

	#--------------------------
	# Permission Checks
	#--------------------------
	my $conf = $self->get_bot_conf( $pci );
	my $root_mask = $conf->{root_mask};

	$said->{by_root} = ( $said->{ sender_raw } =~ $root_mask );
	$said->{by_chan_op} = $pci->is_channel_operator( $said->{channel}, $said->{name} );
	warn Data::Dumper->Dump([[$pci->nick_channels($said->{name})]], ["NICK_CHANS"]);
	$said->{in_my_chan} = ($pci->nick_channels($said->{name})) ? 1 : 0;
	
	return $said;
}

sub irc_public {
	my $self  = $_[OBJECT];
	my $said = _said( @_ );

	if( $self->is_ignored( $said ) ) {
		warn "Ignoring $said->{name}\n";
		return;
	}

	warn "Yielding to execute_said\n";
	warn Dumper $said;

	$self->dispatch_said( $said );
}

sub irc_msg {
	my $self = $_[OBJECT];
	my $said = _said( @_ );

	return if $self->is_ignored( $said );

	$self->dispatch_said( $said );
}

sub irc_ctcp_action {
	my $self = $_[OBJECT];
	my $said = _said( @_ );
}


sub irc_join {
	my $self = $_[OBJECT];
}

sub irc_invite {
	my( $self, $kernel, $sender, $inviter, $channel ) = @_[OBJECT,KERNEL,SENDER,ARG0,ARG1];

	$kernel->post( $sender, join => $channel );

}

# Naturally this is called after we've successfully
# connected to an irc server so we queue up some 
# channel joins and so forth.
sub irc_001 {
	my( $self, $kernel, $sender ) = @_[OBJECT,KERNEL,SENDER];
	my $bot_conf = $self->get_bot_conf( $sender->ID );

	my $channels = $bot_conf->{channel};
	
	# GIANT HACK
	if( $bot_conf->{server} =~ /freenode/ ) {
		my $fh;
		open $fh, "/home/simcop2387/nickservpass" or open $fh, "/home/simcop/nickservpass" or goto HACKEND; #sorry
		my $pass = <$fh>;
		chomp $pass;

		$kernel->post( $sender, privmsg => 'nickserv', "identify $pass" );
	}
	HACKEND:
	# END HACK

	$kernel->delay_add(comfuck=>50);
	
	# May be an array ref.
	for( ref $channels ? @$channels : $channels ) {
		$kernel->post( $sender, join => $_ );
	}
}

sub irc_474 {
	my( $self, @args ) = @_[OBJECT,ARG0..$#_];

	warn "Error, banned from channel: @args\n";
}

# Triggered by a delay_set whenever a line is added to dynamic_ignores
sub clear_dynamic_ignore {
	my( $self, $pci_id, $nick ) = @_[OBJECT,ARG0,ARG1];


	shift @{$self->{dynamic_ignores}->{$pci_id}->{$nick}};
}

sub irc_ctcp_chat {
	my( $self, $sender, $user, $target ) = @_[OBJECT,SENDER,ARG0,ARG1];
	my $pci = $self->get_component( $sender->ID );

	warn "Matching: ", $pci->nick_name, " against $target->[0]\n";

	if( l_irc($pci->nick_name) eq l_irc($target->[0]) ) {
		$pci->yield( dcc => (parse_user $user)[0], 'CHAT' );
	}
}

sub irc_dcc_request {
	my( $self, $sender, $user, $type, $cookie ) = @_[OBJECT,SENDER,ARG0,ARG1,ARG3];
	my $pci = $self->get_component( $sender->ID );

	if( lc($type) eq 'chat' ) {
		$pci->yield( dcc_accept => $cookie );
	}
}

# Should always be chat events at the moment..
sub irc_dcc_start {
	my( $self, $sender, $cookie, $nick ) = @_[OBJECT,SENDER,ARG0,ARG1];

my $welcome = <<'WELCOME';
    ____              ____        __          _____  ____
   / __ )__  ____  __/ __ )____  / /_   _   _|__  / / __ \
  / __  / / / / / / / __  / __ \/ __/  | | / //_ < / / / /
 / /_/ / /_/ / /_/ / /_/ / /_/ / /_    | |/ /__/ // /_/ /
/_____/\__,_/\__,_/_____/\____/\__/    |___/____(_)____/
WELCOME

$welcome .= "Hello $nick. Welcome to BuuBot's dcc chat.\nAll plugins are available, try 'plugins' and 'help plugins' for a list.";

	$poe_kernel->post( $sender => dcc_chat => $cookie, $welcome );
}

sub irc_dcc_chat {
	my( $self, $sender, $cookie, $nick, $text ) = @_[OBJECT,SENDER,ARG0,ARG1,ARG3];
	my $pci = $self->get_component( $sender->ID );

	my $said = _said( @_ );
	$said->{dcc_id} = $cookie;

	return if $self->is_ignored( $said );

	warn "================================== HOST $_[ARG4] =========================\n";

	use Data::Dumper;
	warn Dumper $said;

	$self->dispatch_said( $said );
}


#-----------------------------------------------------------------------------
# PUBLIC POE API
#-----------------------------------------------------------------------------
sub external_message {
	my( $self, $server, $nick, $channel, $message ) = @_[OBJECT,ARG0,ARG1,ARG2,ARG3];

	warn "Received external message, $server, $nick, $channel, $message\n";

	for my $pci_id ( keys %{ $self->{bot_confs} } ) {
		my $conf = $self->{bot_confs}->{$pci_id};
		my $poco_irc = $self->get_component($pci_id);

		if( $conf->{server} eq $server
			and ( $conf->{nick} eq $nick or $conf->{botname} eq $nick )
			and exists $poco_irc->channels()->{$channel} 
		) {
			warn "Sending private message: $pci_id, $channel, $message\n";
			$self->get_component($pci_id)->yield( privmsg => $channel => $message );
		}
	}
}

sub channel_list {
	my( $self, $kernel, $sender ) = @_[OBJECT,KERNEL,SENDER];
		
	my $channels;
	for( keys %{ $self->{irc_components} } ) {
		my $poco_irc = $self->{irc_components}->{$_};
		my $poco_conf = $self->{bot_confs}->{$_};

		$channels->{ $poco_conf->{server} }
			->{ $poco_conf->{nick} || $poco_conf->{botname} }
				= [ keys %{ $poco_irc->channels } ];
	}

	return $channels;
}

sub plugin_output {
	my( $self, $said, $text ) = @_[OBJECT,ARG0,ARG1];

	utf8::decode( $text );

	return unless $text =~ /\S/;
	$text =~ s/\0/\\0/g; # Replace nulls to prevent them truncating strings we attempt to output.

    if ($text =~ /DCC\s+SEND\s+/)
    {
    	if (exists($said->{forwarding}) && defined($said->{forwarding}))
    	{
    		$said->{forwarding} = undef; #unset forwarding, we will never forward to someone with this.
    		$text = "I can't forward that to another user because of the contents, it might trigger an exploit that would get both me and you in trouble.";
    	}
    	elsif ($said->{channel} ne "*irc_msg")    		#we don't care about it if they're doing it to themselves in /msg
    	{
    		$text = "I can't do that, if I did both you and I could get in trouble.";
    	}
    }
        #this forwards messages to priv_msg for users
        if (exists($said->{forwarding}) && defined($said->{forwarding}) && ($said->{forwarding} =~ /\S/))
        {
           my $copy = {%$said}; #make a shallow copy of $said
           delete $copy->{forwarding};
           $copy->{channel} = "*irc_msg";
           $copy->{name} = $said->{forwarding};
           my $newtext = $said->{name} . " wanted you to know: ". $text;
           $_[KERNEL]->yield(plugin_output => $copy, $newtext);
	   $said->{channel} = "*irc_msg";
           delete $said->{forwarding};
	   $_[KERNEL]->yield(plugin_output => $said, "Told ".$copy->{name}." about ".$text);
           return;
        }

	my $pci = $self->get_component( $said->{pci_id} );

	# sub send_text( $said, $text )  !
	if( $said->{channel} eq '*irc_msg' ) {
		my $messages_sent = 0;

		MESSAGES: for my $text ( split /\r?\n/, $text ) {

			# Send multiple messages if we're talking in a private chat
			# Note that in the future we'll probably want to generalize channels
			# that receive multiple lines and those that don't..
			while( length $text ) {
				my $substr = substr( $text, 0, 400, '' );
				$pci->yield( privmsg => $said->{name} => $substr );

				# Try to avoid sending too many lines, since it may be annoying
				# and it tends to prevent the bot from sending other messages.

				last MESSAGES if $messages_sent++ > 5;
			}
		}
	}
	elsif ( $said->{channel} eq '*dcc_chat' ) { 
		$pci->yield( dcc_chat => $said->{dcc_id} => $text );
	}
	else {
		$text =~ s/\r?\n/ /g;
		$pci->yield( privmsg => $said->{channel} => "$said->{name}: $text" );
	}

}

sub handle_special_commands {
	my( $self, $kernel, $said, @command ) = @_[OBJECT,KERNEL,ARG0,ARG1..$#_];
	my $pci = $self->get_component($said->{pci_id});

	$pci->yield( @command );
}

1;
