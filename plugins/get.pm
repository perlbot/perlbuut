
package Bot::BB3::Plugin::Get;
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

sub new {
  my ($class) = @_;

  my $self = bless {}, $class;
  $self->{name} = "get";
  $self->{opts} = {
    command => 1,
  };

  return $self;
}


sub command {
	my( $self, $said, $pm ) = @_;

  print STDERR "in get command plugin\n";

	my $ua = LWP::UserAgent->new( agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko, really Perlbot) Chrome/45.0.2454.85 Safari/537.36" );
	my $url;

  print STDERR "Checking ".$said->{body}." for urls\n";

	if( $said->{body} =~ s{(https?://\S+)\s*}{} ) {
    print STDERR "First check found, $1\n";
		$url = $1;
	}
	elsif( $said->{body} =~ s/(\S+)\s*// ) {
    print STDERR "Found bare domain/url $1\n";
		$url = "http://$1";
	}
	else {
    print STDERR "Got broken url\n";
		return ('handled', "That doesn't look like a url to me.");
	}

  print STDERR "GOT URL: $url\n";

	my $resp = $ua->get( $url );

	if( not $resp ) {
		print STDERR "Couldn't fetch [$url] you failure";
		return('handled', "Couldn't fetch [$url] $resp");
	}
    
  my @text;
  my $document = HTML::TreeBuilder::XPath->new_from_content( $resp->decoded_content );
  if (!$document) { 
      print "Could not parsinate that page!";
  }
  # just the xpath left
  if ($said->{body} =~ /^\s*\.\*\s*$/) {
      print $resp->decoded_content;
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
  
  my @values = map { local $_ = "$_"; s/\s+/ /g;s/^ +//; s/ +$//; $_} @text;

  print STDERR "text? @text\n";

  return ('handled', join("", @values)); 
}

"Bot::BB3::Plugin::Get";

__DATA__
get http://url/ //xpath - get page from interents, extract the xpath, show it to people. (Xpath defaults to '//title' +  '//body' ) spaces squashed too
