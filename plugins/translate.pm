use strict;
use warnings;
use Bing::Translate;



return sub {
	my( $said ) = @_;

open(my $fh, "<etc/bing_secret.txt") or die "Couldn't read $!";
my $cid = "Perlbot";
my $secret = <$fh>;
chomp $secret;
close($fh);

my $tro = Bing::Translate->new($cid, $secret);

    if ($said->{body} =~ /^\s*(?<from>\S+)\s+(?<to>\S+)\s+(?<text>.*)$/) {
#        print $secret;
        print $tro->translate($+{text}, $+{from}, $+{to});
    } else {
        print "help text";
    }

    return('handled');
}

__DATA__
translate <from> <to> <text> - Translate using the Bing Translation API.
