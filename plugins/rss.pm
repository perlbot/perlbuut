use XML::RSS::Parser;
use strict;

no warnings 'void';
sub {
	my( $said, $pm ) = @_;
	my $feed_uri = $said->{recommended_args}->[0];

	print "Couldn't find a url to fetch!" and return
		unless $feed_uri;
	
	my $parser = XML::RSS::Parser->new;
	my $feed = $parser->parse_uri( $feed_uri ) #TODO check for http:// schema
		or ( print "Couldn't parse $feed_uri because", $parser->errstr and return );
	
	for( $feed->query("//item/title") ) {
		print $_->text_content;
	}

}

__DATA__
Returns small list of headlines from an RSS feed. Syntax, fetch_rss http://example/rss
