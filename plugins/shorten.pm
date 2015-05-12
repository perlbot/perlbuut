
no warnings 'void';
sub {
	my( $said, $pm ) = @_;

use WWW::Shorten::TinyURL;
use WWW::Shorten 'TinyURL';

	print "New link: ", WWW::Shorten::TinyURL::makeashorterlink($said->{body}) // $said->{body};
}


__DATA__
shorten <url> returns the "short form" of a url. Defaults to using tinyurl.
