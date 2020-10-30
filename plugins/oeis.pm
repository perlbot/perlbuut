# OEIS plugin to buubot3 by b_jonas

use warnings;
use strict;
use CGI;
use LWP::Simple;
use WWW::Shorten 'TinyURL';

sub query_oeis {
    my ($q)=@_;

	warn 1;
	if( $q =~ /^\s*(?:(?:help|wtf|\?|\:)\s*)?$/i )
	{
		return([], ["see http://oeis.org/"]);
	}
	warn 2;
	my $uri = "http://oeis.org/search?q=" . CGI::escape($q)."&fmt=text";
	local $_ = get($uri); # change this in the real plugin
	warn 2.5;
	if (/^Showing .* of (\d+)/mi) {
		my $nrfound = $1;
		unless( /^%N (\S+) (.*)/m )
		{
			return([ "Reply from OEIS in unknown format 2"],[]);
		}
		warn 3;
		my($anum, $title) = ($1, $2);
		my $elts_re = /^%V/m ? qr/^%[VWX] \S+ (.*)/m : qr/^%[STU] \S+ (.*)/m;
		my $elts = join ",", /$elts_re/g;
		$elts =~ s/,,+/,/g;
		warn 3.5;
		if (1 == $nrfound) {
			my $outuri = sprintf "http://oeis.org/%s", $anum;
			return ([],[sprintf( "%s %.256s: %.512s", $outuri, $title, $elts)]);
		} else {
			my $outuri1 = "http://oeis.org/searchs?q=" . CGI::escape($q);
			warn 3.6;
#			my $outuri = makeashorterlink($outuri1) || $outuri1;
			return([], [sprintf( "%s %.10s(1/%d) %.256s: %.512s", $outuri1, $anum, $nrfound, $title, $elts)]);
		}
	} elsif (/^no matches/mi) {
		return([], ["No matches found"]);
		warn 4
	} else {
	warn 5;
		return([ "Reply from OEIS in unknown format: $_"], []);
	}
}

sub {
	my($said) = @_;
	my $q = $said->{"body"};
    my ($err, $out) = query_oeis($q);
	print "Error: @$err\n" if @$err;
	print "@$out\n";
}
__DATA__
Search for a sequence in the On-Line Encyclopedia of Integer Sequences (http://tinyurl.com/2blo2w) Syntax, oeis 1,1,2,3,5
