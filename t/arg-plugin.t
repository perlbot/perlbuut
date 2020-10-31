#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use lib::relative './lib', '../lib', '..';
use t::simple_plugin;
use Encode qw/encode/;

load_plugin("arg");

check("&n", "perlbot", ['FOO'], "empty but valid");

check("&a", "", ['FOO'], "macro args"); # this one is difficult to test for, it really gets the arguments to the parent macro
check("", "", ['FOO'], "empty arguments, needs better check");

check("&h", "irc.client.example.com", ['FOO'], "host");
check("&c", "##NULL", ['FOO'], "channel");
check("&o", 0, ['FOO'], "is op?");
check("&s", "irc.server.example.com", ['FOO'], "server");

done_testing();
