#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use lib::relative './lib', '../lib', '..';
use t::simple_plugin;
use Encode qw/encode/;

load_plugin("arg");

check("n", "perlbot", [1], "empty but valid");

check("a", "a", [1], "macro args"); # this one is difficult to test for, it really gets the arguments to the parent macro
check("", "", [1], "empty arguments, needs better check");

check("h", "irc.client.example.com", [1], "host");
check("c", "##NULL", [1], "channel");
check("o", 0, [1], "is op?");
check("s", "irc.server.example.com", [1], "server");

done_testing();
