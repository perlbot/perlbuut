#!/usr/bin/env perl

use strict;
use FindBin;
use lib $FindBin::Bin.'/../lib';
use EvalServer::Sandbox;

EvalServer::Sandbox::run_eval();
1;
