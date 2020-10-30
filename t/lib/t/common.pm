package t::common;

use strict;
use warnings;
use utf8;
use parent 'Exporter';

our @EXPORT=qw/load_plugin make_said/;

# This doesn't let us test multiple plugins at a time, which might be needed for the compose plugin
# This can be fixed later
our $plugin;

sub load_plugin {
    my $name = shift;

    my $fullname = "plugins/$name.pm";

    $plugin = require $fullname;
}

sub make_said
{
    my ($body, $who, $server, $channel) = @_;

    # TODO make this fill out a lot more of the said object

    my @args = split /\s+/, $body; 
    my $said = {
      body => $body,
      recommended_args => \@args,
    };
}

1;
