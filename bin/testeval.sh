#!/bin/bash

read -r -d '' CODE <<'EOC'
perl BEGIN {$ENV{TMPDIR}="/tmp"}; use File::Temp; File::Temp->new()."";
EOC

echo --------
echo $CODE
echo --------

rm -f ./jail/noseccomp
echo $CODE | sudo strace -ojail/killed.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./bin/test_eval.pl
touch ./jail/noseccomp
echo $CODE | sudo strace -ojail/alive.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./bin/test_eval.pl
rm -f ./jail/noseccomp
