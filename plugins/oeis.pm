# OEIS plugin to buubot3 by b_jonas

use warnings;
use strict;
use CGI;
use LWP::Simple;
use WWW::Shorten 'Metamark';

sub {
	my($said) = @_;
	my $q = $said->{"body"};

	warn 1;
	if( $q =~ /^\s*(?:(?:help|wtf|\?|\:)\s*)?$/i )
	{
		print "see http://oeis.org/";
		return;
	}
	warn 2;
	my $uri = "http://oeis.org/?fmt=data&q=" . CGI::escape($q);
	local $_ = get($uri); # change this in the real plugin
	warn 2.5;
	if (/^Displaying .* of (\d+) results?/mi) {
		my $nrfound = $1;
                # this is so fucked up
		unless( m|<a href="[^"]+">(A\d+)</a>.*?align=left>(.*)<br>|si )
		{
			print "Reply from OEIS in unknown format 2";
			return;
		}
		warn 3;
		my($anum, $title) = ($1, $2);
		my $elts_re = /^%V/m ? qr/^%[VWX] \S+ (.*)/m : qr/^%[STU] \S+ (.*)/m;
		my $elts = join ",", /$elts_re/g;
		$elts =~ s/,,+/,/g;
		warn 3.5;
		if (1 == $nrfound) {
			my $outuri = sprintf "http://oeis.org/A%.10s", $anum;
			print sprintf "%s %.256s: %.512s", $outuri, $title, $elts;
		} else {
			my $outuri1 = "http://oeis.org/?q=" . CGI::escape($q);
			warn 3.6;
			print sprintf "%s %.10s(1/%d) %.256s: %.512s", $outuri1, $anum, $nrfound, $title, $elts;
		}
	} elsif (/^no matches/mi) {
		print "No matches found";
		warn 4
	} else {
	warn 5;
		print "Reply from OEIS in unknown format: $_";
	}
}

__DATA__
Search for a sequence in the On-Line Encyclopedia of Integer Sequences (http://tinyurl.com/2blo2w) Syntax, oeis 1,1,2,3,5
