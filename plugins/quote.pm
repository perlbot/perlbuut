use Bot::BB3::MacroQuote ();

no warnings 'void';
sub {
	my( $said ) = @_;
	
	$said->{body} =~ /\A\s*(\w+)\s?(.*)\z/s # note: only one space after the quoting mode so we can quote strings starting with space
		or return;
	my($mode, $str) = ($1, $2);
	
	print Bot::BB3::MacroQuote::quote($mode, $str);
}

__DATA__
Escape a string to prepare for interpolation in an eval program code.  Syntax is quote m string, with one space after quoting mode m which can be: z (no-op), c (c-like hex escapes), d (with delimiters), e, f, h.