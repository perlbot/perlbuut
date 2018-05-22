use LWP::UserAgent;
use HTML::TreeBuilder::XPath;

package 
  XML::XPathEngine::Function {
  sub string_join {
    my $self = shift;
    my ($node, @params) = @_;
    die "concat: Too few parameters\n" if @params < 2;
    my $joiner = pop @params;
    my $string = join($joiner->string_value, map {$_->string_values} @params);
    return XML::XPathEngine::Literal->new($string);
  }
};


sub {
	my( $said ) = @_;

	my $ua = LWP::UserAgent->new( agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36" );
	my $url;


	if( $said->{body} =~ s{(https?://\S+)\s*}{} ) {
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
  if ($said->{body} =~ /^\s*\.\*\s*$/) {
      print $resp->content;
  } elsif ($said->{body}) {
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
