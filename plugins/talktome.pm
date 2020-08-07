use LWP::UserAgent;
use JSON::MaybeXS qw/encode_json/;

sub {
	my( $said ) = @_;

	my $ua = LWP::UserAgent->new( agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko, really Perlbot) Chrome/45.0.2454.85 Safari/537.36" );
	my $url = "https://nodered.simcop2387.info/perlbot/talktome/";

  my $alexatest = {
    text => $said->{body},
    who => $said->{name},
  };

	my $resp = $ua->put( $url, "Content-Type" => "application/json", Content => encode_json($alexatest) );

	if( not $resp ) {
		print "Couldn't fetch [$url] you failure";
		return;
	}

  print "You have sent an annoyance to simcop2387";
}

__DATA__
talktome - Send a message to simcop2387's NSA listening device to be read out loud.
