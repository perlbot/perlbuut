use LWP::UserAgent;
use URI::Escape qw/uri_escape/;

no warnings 'void';
sub {
	my( $said ) = @_;

    my $ua = LWP::UserAgent->new();
    my $foo = $ua->get('http://xn--55d.com/cgi/yep2.pl?txt='.uri_escape($said->{body}));
    if ($foo->is_success) {
        print $foo->content;
    } else {
        print $foo->status_line;
    }
}

__DATA__
head http://url/; returns the response code and server type from a HEAD request for a particular url.
