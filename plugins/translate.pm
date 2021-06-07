use strict;
use warnings;
use LWP::UserAgent;
use JSON::MaybeXS qw/decode_json encode_json/;
use Data::Dumper;

my $ua = LWP::UserAgent->new();


return sub {
	my( $said ) = @_;


    if ($said->{body} =~ /^\s*(?<from>\S+)\s+(?<to>\S+)\s+(?<text>.*)$/) {
      my $json = {
        source_language => $+{from},
        target_language => $+{to},
        text => $+{text}
      };

      my $resp = $ua->post("http://192.168.1.229:10000/translate_text", Content => encode_json($json));

      my $cont = $resp->decoded_content();
      my $output = decode_json($cont);

      print Dumper $output;

    } else {
        print "help text";
    }

    return('handled');
}

__DATA__
translate <from> <to> <text> - Translate using the Bing Translation API.
