#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use Test::Differences qw/ eq_or_diff /;
use Capture::Tiny qw/capture/;
use lib '.';
my $sub = require plugins::core;

sub make_said
{
    my ($body, $who, $server, $channel) = @_;

    my @args = split /\s+/, $body; 
    my $said = {
      body => $body,
      recommended_args => \@args,
    };
}

sub check
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $body, $want, $res, $blurb ) = @_;

    my $said = make_said($body);
    my ($out, $err, @result) = capture {
      $sub->( $said );
    };

    return eq_or_diff( $err, "", "no errors" )
        && eq_or_diff(\@result, $res, "Result is correct")
        && eq_or_diff( $out, $want, $blurb );
}

check("", "usage: core Module::Here", ["handled"], "usage help");
check("CGI", "CGI Added to perl core as of 5.004 and deprecated in 5.019007", ["handled"], "deprecated");
check("Data::Dumper", "Data::Dumper Added to perl core as of 5.005", ["handled"], "never gonna give it up");
done_testing();
