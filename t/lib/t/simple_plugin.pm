package t::simple_plugin;

use strict;
use warnings;
use utf8;
use parent 'Exporter';
use t::common;

our @EXPORT=qw/load_plugin make_said check/;

use Test::Differences qw/ eq_or_diff /;
use Capture::Tiny qw/capture/;

sub check
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $body, $want, $res, $blurb ) = @_;

    my $said = make_said($body);
    my ($out, $err, @result) = capture {
      $t::common::plugin->( $said );
    };

    return eq_or_diff( $err, "", "no errors" )
        && eq_or_diff(\@result, $res, "Result is correct")
        && eq_or_diff( $out, $want, $blurb );
}

1;
