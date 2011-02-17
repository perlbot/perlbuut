use LWP::UserAgent;
use HTML::TreeBuilder;
use URI::Escape qw/uri_escape/;

sub {
	my( $said )= @_;
	my $query = uri_escape( $said->{body} );

	my $ua = LWP::UserAgent->new( agent => "Mozilla 5.0" );

	my $resp = $ua->get( "http://google.com/search?q=$query" );

	if( not $resp->is_success ) {
		print "Sorry, got a " . $resp->code . " from google. ";
		return;
	}

	my $tree = HTML::TreeBuilder->new_from_content( $resp->content );

	my $first = $tree->look_down( class => "l" );
	my $first_desc = $tree->look_down( class => "s" );

	print $first->attr('href'), " - ";
	print $first->as_text;
	print " ";

	for( $first_desc->content_list ) {
	  last if ref $_ and $_->tag eq 'cite';

		  print ref $_ ? $_->as_text : $_;
	}
}


__DATA__
google <Query>; Returns the link and description of the first result from querying google.
