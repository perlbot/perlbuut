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
zippit <text>; gives back a random saying from the zippit plugin
