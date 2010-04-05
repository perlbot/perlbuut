use WWW::Shorten 'Metamark';
use URI::Encode qw(uri_encode);

no warnings 'void';
sub {
	my( $said, $pm ) = @_;

    my $url = "";
    
	if ($said->{body} =~ /-q\s+(.*)/i) #faq questions
	{#http://perldoc.perl.org/search.html?q=foo+bar
	  my $trimmed = $1;
	  $trimmed =~ s/^\s*(\S+)\s*$/$1/;
	  my $query = uri_encode($trimmed);
	  $query =~ s/%20/+/g;
	  $url = "http://perldoc.perl.org/search.html?q=".$query;
	}
	elsif ($said->{body} =~ /-f\s+(.*)/i) #functions, only use the first part of a multiword expression
	{
		#http://perldoc.perl.org/functions/abs.html
		my $func = $1;
		print "orig func: $func\n";
		$func =~ s/^\s*(.*)\s*$/$1/; #trim whitespace
		$func = lc($func); #all functions are lowercase, except the exception below
		
		$func = "-X" if ($func eq "-x"); #only case where it isn't lowercase, its easier to test at this point
		
		$url = "http://perldoc.perl.org/functions/".$func.".html"
	}
	elsif ($said->{body} =~ /-m\s+(.*)\s*$/i) # got a module!
	{#http://search.cpan.org/search?query=foo%3ABar&mode=all
	  my $query = uri_encode($1);
	  $query =~ s/%20/+/g;
	  $url = "http://search.cpan.org/search?query=".$query."&mode=module";
	}
	elsif ($said->{body} =~ /::/) #module, go to cpan also
	{
	  my $trimmed = $said->{body};
	  $trimmed =~ s/^\s*(\S+)\s*$/$1/;
	  my $query = uri_encode($trimmed);
	  $query =~ s/%20/+/g;
	  $url = "http://search.cpan.org/search?query=".uri_encode($said->{body})."&mode=module";
	}
	else # we've got just a plain word, use it as a doc title
	{ #http://perldoc.perl.org/perlrun.html
	  if ($said->{body} =~ /\s*(\S+)\s*/)
	  {
	  	$url = "http://perldoc.perl.org/$1.html";
	  }
	  else
	  {
	  	print "Please request a valid section of perl documentation; you may also use, -q, -f, and -m just like on the command line";
	  	return;
	  }
	}

	print "Your documentation is available at: ", makeashorterlink($url);
}