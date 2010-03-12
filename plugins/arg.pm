use Bot::BB3::MacroQuote ();
no warnings 'void';
sub {
	my( $said ) = @_;
	
	my $flags = $said->{body};
	my($quotemode, $wordnr, $auxfield) = ("z", 0, "macro_arg");
	$flags =~ s/\&(\w+)// and
		$auxfield = $1;
	$flags =~ s/([a-zA-Z]+)// and
		$quotemode = $1;
	$flags =~ s/(-?[0-9]+)// and
		$wordnr = $1;
	
	my %auxfield_abbrev = (qw"
		macro_arg macro_arg arg macro_arg a macro_arg
		name name nick name n name
		ircname ircname username ircname r ircname
		host host h host
		sender_raw sender_raw u sender_raw
		channel channel c channel
		by_chan_op by_chan_op o by_chan_op
		server server s server network server
		captured captured
	");
	my $f = $auxfield_abbrev{$auxfield};
	my $str = $f && $said->{$f};

	if (0 < $wordnr) {
		$str = (split " ", $str)[$wordnr - 1];
	} elsif ($wordnr < 0) {
		$str = (split " ", $str, 1 - $wordnr)[-$wordnr];
	}
	
	print Bot::BB3::MacroQuote::quote($quotemode, $str);
};

__DATA__
Prints macro argument in a function macro factoid.  Takes optional quoting mode letter or signed number for word splitting; or '&n' or '&c' etc to access extra info.
