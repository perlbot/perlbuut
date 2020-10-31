#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use lib::relative './lib', '../lib', '..';
use t::simple_plugin;
use Encode qw/encode/;

load_plugin("echo");

check("", "", [1], "empty but valid");
check("Hello World", "Hello World", [1], "HW");
check("\N{SNOWMAN}", encode("utf8", "\N{SNOWMAN}"), [1], "Encoding correctly");
done_testing();
