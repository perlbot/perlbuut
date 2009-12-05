package Bot::BB3::PluginConfigParser;
use strict;
use Parse::RecDescent;
use Bot::BB3::Logger;

local $/;
my $grammar = <DATA>;
my $parser = Parse::RecDescent->new( $grammar );

sub parse_file {
	my( $package, $filename ) = @_;

	open my $fh, "< $filename" or die "$filename: $!";
	local $/;
	my $filecontents = <$fh>;

	$parser->start( $filecontents );
}

1;

__DATA__

start: server(s)
	{ $item[1] }
server: 'server' server_name '{' channel(s) '}'
	{ [ $item[1], $item[2], $item[4] ] }
channel: 'channel' channel_name '{' plugin(s) '}'
	{ [ $item[1], $item[2], $item[4] ] }
plugin: 'plugin' plugin_name '{' option(s?) '}'
	{ [ $item[1], $item[2], { map @$_, @{$item[4]} } ] }
option: key ':' value semicolon(?)
	{ [$item[1], $item[3]] }
semicolon: ';'

server_name: quoted_string | /[\w.]+/ | '*'
	{ $item[1] }
channel_name: quoted_string | /#\w+/ | '*'
	{ $item[1] }
plugin_name: quoted_string | /\w+/ | '*'
	{ $item[1] }
key: quoted_string | /\w+/
	{ $item[1] }
value: quoted_string | /\w+/
	{ $item[1] }
quoted_string: /"[^"]+"/
	{ my $str = $item[1]; $str =~ s/^"//; $str =~ s/"$//; $str } 
