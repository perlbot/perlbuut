#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More tests => 4;
use Test::Differences qw/ eq_or_diff /;
use lib '.';
use plugins::unicode;

sub check
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $body, $want, $blurb ) = @_;
    my ( $err, $out ) = unip( map speng($_), split " ", $body );

    return eq_or_diff( $err, [], "no errors" )
        && eq_or_diff( $out, $want, $blurb );
}

# TEST*2
check(
    "perl",
    [
        "U+0070 (70): LATIN SMALL LETTER P [p]",
        "U+0065 (65): LATIN SMALL LETTER E [e]",
        "U+0072 (72): LATIN SMALL LETTER R [r]",
        "U+006C (6c): LATIN SMALL LETTER L [l]",
    ],
    "ascii"
);

# TEST*2
check( "💟", [ "U+1F49F (f0 9f 92 9f): HEART DECORATION [💟]", ],
    "emoji", );

