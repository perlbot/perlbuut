package Bot::BB3::Plugin::Perldoc; 

use strict;
use warnings;

use URI::Encode qw(uri_encode);

no warnings 'void';

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = 'perldoc';
	$self->{opts} = {
		command => 1,
    handler => 1,
	};

  $self->{aliases} = ['perldoc'];

	return $self;
}

sub get_conf_for_channel {
    my ($self, $pm, $server, $channel) = @_;
	my $gc = sub {$pm->plugin_conf($_[0], $server, $channel)};
	
	# Load factoids if it exists, otherwise grab the old nfacts setup
	my $conf = $gc->("perldoc");
	return $conf;
}

sub handle {
	my( $self, $said, $pm ) = @_;
  my $conf = $self->get_conf_for_channel($pm, $said->{server}, $said->{channel});

  my $url = "";

  if (!$said->{addressed} && !$conf->{addressed} && $said->{body} =~ /^perldoc\s+(.*?)$/i) {
    local $said->{body} = $1;

    my ($handled, $result) = $self->command($said, $pm);

    if ($handled eq "handled") {
      return $result;
    } 
  }
}

sub command {
	my( $self, $said, $pm ) = @_;

  my $url = "";

	if ($said->{body} =~ /-(q|s)\s+(.*?)\s*(?:#.*)?\s*$/i) #faq questions
	{#http://perldoc.perl.org/search.html?q=foo+bar
	  my ($oper, $trimmed) = ($1, $2);
	  $trimmed =~ s/^\s*(\S+)\s*$/$1/;
	  my $query = uri_encode($trimmed, {"encode_reserved" => 1});
	  $query =~ s/%20/+/g;

    if ($oper eq 'q') {
  	  $url = "https://perldoc.pl/search?no_redirect=1&q=".$query."#FAQ";
    } else {
  	  $url = "https://perldoc.pl/search?q=".$query;
    }
#	  $url = makeashorterlink($url);
	}
	elsif ($said->{body} =~ /-f\s+(\S+)\s*/i) #functions, only use the first part of a multiword expression
	{
		#http://perldoc.perl.org/functions/abs.html
		my $func = $1;

		$func =~ s/^\s*(.*)\s*$/$1/; #trim whitespace
		#$func = lc($func); #all functions are lowercase, except the exception below
		
		$func = "-X" if ($func eq "-x"); #only case where it isn't lowercase, its easier to test at this point
		
		$url = "https://perldoc.pl/functions/".$func
	}
	elsif ($said->{body} =~ /-v\s+(\S+)\s*/i) #functions, only use the first part of a multiword expression
	{
		my $var = uri_encode($1, {"encode_reserved" => 1});

		$url = "https://perldoc.pl/variables/".$var
	}
	elsif ($said->{body} =~ /-m\s+(\S+)\s*/i) # got a module!
	{#http://search.cpan.org/search?query=foo%3ABar&mode=all
	  my $query = uri_encode($1);
#	  $query =~ s/%20/+/g;
	  $url = "https://perldoc.pl/".$query;
#	  $url = makeashorterlink($url);
	}
	elsif ($said->{body} =~ /::/) #module, go to cpan also
	{
	  my $trimmed = $said->{body};
	  $trimmed =~ s/^\s*(\S+)\s*(?:#.*)?$/$1/;
	  my $query = uri_encode($trimmed);
	  $query =~ s/%20/+/g;
	  $url = "https://perldoc.pl/$query";
#	  $url = makeashorterlink($url);
	}
	else # we've got just a plain word, use it as a doc title
	{ #http://perldoc.perl.org/perlrun.html
	  if ($said->{body} =~ /^\s*(\S+)\s*(?:#.*)?$/)
    {
	  	$url = "https://perldoc.pl/$1";
	  }
	  else
	  {
      if ($said->{addressed}) {
  	  	return("handled", "Please request a valid section of perl documentation; you may also use, -q, -f, and -m just like on the command line");
      }
	  	return;
	  }
	}

  if (!$said->{nested}) {
  	return ("handled", "Your documentation is available at: $url");
  } else {
  	return ("handled", $url);
  }
}

"Bot::BB3::Plugin::Perldoc"; 

__DATA__
Provide links to perldoc pages and module documentation on metacpan.  Takes most options like the perldoc command line program.
