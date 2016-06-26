package Bot::BB3::Roles::Evalpastebin;

use POE;
use POE::Component::Server::TCP;
use strict;
use Data::Dumper;
use JSON::MaybeXS;

sub new {
	my( $class, $conf, $pm ) = @_;

	my $self = bless { conf => $conf, pm => $pm }, $class;
	
    $self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/_start receive_paste/ ]
		]
	);

	return $self;
}

sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];
	my $conf = $self->{conf};

    # TODO setup TCP server.
    $self->{server} = POE::Component::Server::TCP->new(
        Port => 1784,
        Address =>'127.0.0.1',
        ClientFilter => "POE::Filter::Line",
        ClientInput => \&receive_paste,
    );
	
    $kernel->alias_set( "evalpastebin_role" );
	$kernel->sig("DIE" => 'sig_DIE' );
}

sub receive_paste {
    my ($kernel, $line) = @_[KERNEL, ARG0];

    chomp $line;

    if ($line eq 'GET_CHANNELS') {
        my $channel_list = $kernel->call("Bot::BB3::Roles::IRC", "channel_list");
        $_[HEAP]{client}->put(encode_json($channel_list));
    } else {
        my ($alert_channel, $link, $who, $summary) = split(/\x1E/, $line);

        if( $alert_channel !~ /^\s*---/ ) { # Ignore things like "---irc.freenode, skip server names
            my($server,$nick,$channel) = split /:/,$alert_channel,3;

            $_[KERNEL]->post( "Bot::BB3::Roles::IRC", 
                external_message => 
                    $server, 
                    $nick, 
                    $channel,
                "$who pasted a new file at $link - $summary"
            );
        }
    }
}

sub sig_DIE {
	# Do nothing, we're ignoring fatal errors from our child, poco-server-simplehttp. I think we don't need to respawn them.
}

1;
