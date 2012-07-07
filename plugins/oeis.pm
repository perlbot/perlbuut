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
		print "see http://tinyurl.com/7xmvs and http://tinyurl.com/2blo2w";
		return;
	}
	warn 2;
	my $uri = "http://www.research.att.com/~njas/sequences/?q=" . CGI::escape($q) . "&n=1&fmt=3";
	local $_ = get($uri); # change this in the real plugin
	warn 2.5;
	if (/^Results .* of (\d+) results/mi) {
		my $nrfound = $1;
		unless( /^%N (\S+) (.*)/m )
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
			my $outuri = sprintf "http://tinyurl.com/4zq4q/%.10s", $anum;
			print sprintf "%s %.256s: %.512s", $outuri, $title, $elts;
		} else {
			my $outuri1 = "http://www.research.att.com/~njas/sequences/?q=" . CGI::escape($q);
			warn 3.6;
			my $outuri = makeashorterlink($outuri1) || $outuri1;
			print sprintf "%s %.10s(1/%d) %.256s: %.512s", $outuri, $anum, $nrfound, $title, $elts;
		}
	} elsif (/^no matches/mi) {
		print "No matches found";
		warn 4
	} else {
	warn 5;
		print "Reply from OEIS in unknown format";
	}
}

__DATA__
Search for a sequence in the On-Line Encyclopedia of Integer Sequences (http://tinyurl.com/2blo2w) Syntax, oeis 1,1,2,3,5
