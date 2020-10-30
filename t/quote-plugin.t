#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use Test::More;
use lib::relative './lib', '../lib', '..';
use t::simple_plugin;

load_plugin("quote");

check("", "", [], "do nothing");
check('d TESTING HERE', q{"TESTING HERE"}, [1], 'quote d simple');
check('c TESTING HERE', q{TESTING HERE}, [1], 'quote d simple');
check(qq{d "TESTING \nHERE"}, q{"\\x22TESTING \\x0aHERE\\x22"}, [1], 'quote d complex');
check(qq{c "TESTING \nHERE"}, q{\\x22TESTING \\x0aHERE\\x22}, [1], 'quote c complex');
check(qq{e "TESTING \nHERE"}, q{\\x22TESTING\\x20\\x0aHERE\\x22}, [1], 'quote e complex');
check(qq{f "TESTING \nHERE"}, q{"\\x22TESTING\\x20\\x0aHERE\\x22"}, [1], 'quote f complex');
check('h TESTING HERE', q{54455354494e472048455245}, [1], 'quote h');
done_testing();
