use WWW::Shorten 'Metamark';
no warnings 'void';
sub {
	my( $said, $pm ) = @_;

	print "New link: ", makeashorterlink($said->{body});
}


__DATA__
shorten <url> returns the "short form" of a url. Defaults to using xrl.us.
