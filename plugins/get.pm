use Net::INET6Glue::INET_is_INET6;
use LWP::UserAgent;
use HTML::TreeBuilder::XPath;

sub {
	my( $said ) = @_;

	my $ua = LWP::UserAgent->new( agent => "BB3WebAgent! (mozilla)" );
	my $url;

	if( $said->{body} =~ s{(http://\S+)\s*}{} ) {
		$url = $1;
	}
	elsif( $said->{body} =~ s/(\S+)\s*// ) {
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
    
    my @text;
    my $document = HTML::TreeBuilder::XPath->new_from_content( $resp->content );
    if (!$document) { 
        print "Could not parsinate that page!";
    }
    # just the xpath left
    if ($said->{body}) {
        @text = eval{
            $document->findvalues( $said->{body} );
        };
        @text = "Your Xpath didn't match anything"  if 0 == @text;
        @text = "Your Xpath fails: $@"              if $@;
    }
    if (! $said->{body} ){
        @text = ($@,$document->findvalues( '//title' ), ': ',$document->findvalues( '//body' ));
    }
    local $, = ', ';
    
    print map { local $_ = "$_"; s/\s+/ /g;s/^ +//; s/ +$//; $_} @text
}

__DATA__
get http://url/ //xpath - get page from interents, extract the xpath, show it to people. (Xpath defaults to '//title' +  '//body' ) spaces squashed too
