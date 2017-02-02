no warnings 'void';

use Twitter::API;
use Data::Dumper;
use strict;

open(my $fh, "<", "etc/twitterkeys") or die $!;
my ($consumer_key, $consumer_secret) = <$fh>;
close($fh);

chomp $consumer_key;
chomp $consumer_secret;

#die Dumper($consumer_key, $consumer_secret);

my $client = Twitter::API->new_with_traits(
    traits => [qw/ApiMethods AppAuth/],
    consumer_key        => $consumer_key,
    consumer_secret     => $consumer_secret,
    );

# get the appauth token and set it up
my $_r = $client->oauth2_token;
$client->access_token($_r);

sub {
	my( $said ) = @_;
	
# TODO make this also support getting more than one tweet.

    my ($userid) = $said->{body} =~ /^\s*(\S+)/g;

    my $timeline=$client->user_timeline($userid);

    my $tweet = $timeline->[0];

    if ($tweet) {
        my ($time, $text, $id) = @{$tweet}{qw/created_at text id/};
        my $source = $tweet->{user}{name};
        my $url = "https://twitter.com/link/status/$id";

	    print STDERR Dumper($timeline);
        print "<$source> $text $url";
    } else {
        print "No tweets found";
    }

    return ('handled', 'handled');
};
__DATA__
Get the latest tweet from an account
