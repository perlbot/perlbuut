#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More tests => 1;
use lib '.';
use plugins::oeis;

# TEST
like(
    (query_oeis("1,2,6,24"))[1][0],
    qr#https?://oeis\.org/.*?Factorial numbers: n!#ms,
    "factorials",
);
