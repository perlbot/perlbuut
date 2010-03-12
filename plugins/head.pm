use LWP::UserAgent;
no warnings 'void';
sub {
	my( $said ) = @_;

	my $ua = LWP::UserAgent->new( agent => "BB3WebAgent! (mozilla)" );
	my $url;

	if( $said->{body} =~ m{(http://\S+)} ) {
		$url = $1;
	}
	elsif( $said->{body} =~ /(\S+)/ ) {
		$url = "http://$1";
	}
	else {
		print "That doesn't look like a url..";
		return;
	}

	my $resp = $ua->head( $url );

	if( not $resp ) {
		print "Couldn't fetch [$url] you failure";
		return;
	}

	print "$url: " . $resp->code . ": " . $resp->message . ". " . $resp->header("server");
};

__DATA__
head http://url/; returns the response code and server type from a HEAD request for a particular url.
