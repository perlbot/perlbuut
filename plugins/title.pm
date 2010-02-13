use WWW::Mechanize;

sub {
	my( $said ) = @_;

	my $ua = WWW::Mechanize->new( agent => "BB3WebAgent! (mozilla)" );
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

	my $resp = $ua->get( $url );

	if( not $resp ) {
		print "Couldn't fetch [$url] you failure";
		return;
	}

	print "$url: " . $ua->title();
}

__DATA__
head http://url/; returns the response code and server type from a HEAD request for a particular url.
