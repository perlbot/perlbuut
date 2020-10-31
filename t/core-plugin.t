#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use lib::relative './lib', '../lib', '..';
use t::simple_plugin;

load_plugin("core");

check("", "usage: core Module::Here", ["handled"], "usage help");
check("CGI", "CGI Added to perl core as of 5.004 and deprecated in 5.019007", ["handled"], "deprecated");
check("Data::Dumper", "Data::Dumper Added to perl core as of 5.005", ["handled"], "never gonna give it up");
done_testing();
