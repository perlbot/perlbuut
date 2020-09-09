package Bot::BB3::Roles::RestAPI;

use Bot::BB3::Logger;
use POE;
use POE::Component::Server::SimpleHTTP;
use HTTP::Status;
use strict;
use JSON::MaybeXS qw/decode_json encode_json/;

sub new {
	my( $class, $conf, $plugin_manager ) = @_;

	my $self = bless { conf => $conf, pm => $plugin_manager }, $class;

	my $session = $self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/_start handle_request display_page plugin_output sig_DIE/ ]
		]
	);

	return $self;
}

sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];
	my $conf = $self->{conf};

	warn '$conf{http}' . $conf->{http_plugin_port};

	# Create it here so it acts as a child
	$self->{server} = POE::Component::Server::SimpleHTTP->new(
		PORT => $conf->{http_plugin_port},
		ADDRESS => $conf->{http_plugin_addr} || undef,
		ALIAS => 'web_httpd_alias',
		HANDLERS => [
			{
				DIR => '^/request',
				SESSION => "web_interface",
				EVENT => "handle_request",
			},
			{
				DIR => '^/',
				SESSION => "web_interface",
				EVENT => "display_page",
			}

		]
	);

	$kernel->alias_set( "web_interface" );
	$kernel->sig("DIE" => 'sig_DIE' );
}

sub display_page {
	my( $self, $req, $resp, $name, $output, $said ) = @_[OBJECT,ARG0,ARG1,ARG2,ARG3,ARG4];
	
	warn "Display Page Activating: $req - $resp - $output\n";

#  if ($said->{addressed} || $output !~ /^\s*$/) {
#  $output = sprintf '@%s %s', $said->{name}, $output;
#  }

	$resp->code(RC_OK);
	$resp->content_type("application/json");
	$resp->content( encode_json({"body" => $output, saidobj => $said}) );
	
	$_[KERNEL]->post(  web_httpd_alias => 'DONE' => $resp );
}


my %RESP_MAP;

sub handle_request {
	my( $self, $req, $resp, $name ) = @_[OBJECT,ARG0,ARG1,ARG2];

	warn "Request: ", $req->content;

  my $data = decode_json($req->content);
  my $input = $data->{body} // "";
  my $channel = $data->{channel} // "#ERROR";
  my $name = $data->{who} // "ERROR";

	my @args = "2+2";
	warn "Attempting to handle request: $req $resp $input\n";

  my $addressed = 0;

  if ($input =~ /^\@?perlbot/i) {
    $addressed = 1;
    $input =~ s/^\@?perlbot\b[:,;]?\s*//i;
  }

  if ($data->{addressed}) {
    $addressed = 1;
  }

	# This is obviously silly but I'm unable to figure out
	# the correct way to solve this =[
	my $said = {
		body => $input,
		raw_body => $data->{body},
		my_name => 'perlbot',
		addressed => $addressed,
		recommended_args => \@args,
		channel => $channel // "#error",
		name => $name // "ERROR",
		ircname => $name // "ERROR", 
		host => '*special', #TODO fix this to be an actual hostname!
		                    # Make sure it isn't messed up by the alias feature..
		server => $data->{server} // '*special',
    nolearn => 1,
	};
	
	# Avoid passing around the full reference
	$RESP_MAP{ "$resp" } = $resp; 
	$said->{pci_id} = "$resp";

	$self->{pm}->yield( execute_said => $said );
}

sub plugin_output {
	my( $self, $kernel, $said, $output ) = @_[OBJECT,KERNEL,ARG0,ARG1];

  my $name = $said->{name};

  $said->{should_mention} = $output =~ s/^\s*$name://; # Clear the response name
  $said->{should_mention} += 0+$said->{addressed};

	my $resp = delete $RESP_MAP{ $said->{pci_id} };


	$kernel->yield( display_page => undef, $resp, undef, $output, $said ); 
}

sub sig_DIE {
	# Do nothing, we're ignoring fatal errors from our child, poco-server-simplehttp. I think we don't need to respawn them.
}

1;
