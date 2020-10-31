#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use lib::relative './lib', '../lib', '..';
use t::simple_plugin;
use Encode qw/encode/;

load_plugin("unicode");

# TEST*2
check(
    "perl",
    "U+0070 (70): LATIN SMALL LETTER P [p] ".
    "U+0065 (65): LATIN SMALL LETTER E [e] ".
    "U+0072 (72): LATIN SMALL LETTER R [r] ".
    "U+006C (6c): LATIN SMALL LETTER L [l]\n",
    [1],
    "ascii"
);

# TEST*2
check( 
  "💟", 
  encode("utf8", "U+1F49F (f0 9f 92 9f): HEART DECORATION [💟]\n"), 
  [1],
  "emoji" );

done_testing();
