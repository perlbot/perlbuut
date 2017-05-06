#!/bin/bash

read -r -d '' CODE <<'EOC'
ruby print "Hello World";
EOC

echo --------
echo $CODE
echo --------

echo $CODE | sudo strace -f -o killed.log timeout 30 /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./bin/test_eval.pl
