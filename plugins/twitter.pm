no warnings 'void';

use Twitter::API;
use Data::Dumper;
use strict;

open(my $fh, "<", "etc/twitterkeys") or die $!;
my ($consumer_key, $consumer_secret) = <$fh>;
close($fh);

chomp $consumer_key;
chomp $consumer_secret;

use HTML::Entities; 

#die Dumper($consumer_key, $consumer_secret);

my $client = Twitter::API->new_with_traits(
    traits => [qw/ApiMethods AppAuth DecodeHtmlEntities/],
    consumer_key        => $consumer_key,
    consumer_secret     => $consumer_secret,
    );

# get the appauth token and set it up
my $_r = $client->oauth2_token;
$client->access_token($_r);

sub display_tweet {
    my $tweet = shift;

    if ($tweet) {
        my ($time, $text, $id) = @{$tweet}{qw/created_at full_text id/};
        $text //= $tweet->{text};

        my $source = $tweet->{user}{name};
        my $url = "https://twitter.com/link/status/$id";

        unless ($text =~ m|https://t.co/|) {
          print "<$source> $text $url";
        } else {
          print "<$source> $text";
        }

    } else {
        print "No tweets found";
    }
}

sub {
	my( $said ) = @_;
	
# TODO make this also support getting more than one tweet.

    if ($said->{body} =~ /^\s*(#\S+)/ ||
        $said->{body} =~ /^\s*search\s+(.*)/) {
        # hash tags.  omg.
        my $search = $client->search($1, {tweet_mode => "extended"});

        open (my $fh, ">", "/tmp/twitter");
            print $fh Dumper($search);

        my $tweets = $search->{statuses};
        my $tweet = $tweets->@[rand() * $tweets->@*];

        display_tweet $tweet;
    } elsif ($said->{body} =~ m|twitter.com/([^/]+)/status/(\d+)|) {
      my ($userid, $tweetid) = ($1, $2);
      my $tweet = $client->show_status($tweetid, {tweet_mode => "extended"});
      display_tweet($tweet);
    } else {
        my ($userid, $count) = $said->{body} =~ /^\s*(\S+)(?:\s+(\d+))?/g;

        my $timeline=$client->user_timeline($userid, {tweet_mode => "extended"});
        my $tweet = $timeline->[$count//0];

        display_tweet $tweet;
    }

    return ('handled', 'handled');
};
__DATA__
Get the latest tweet from an account
