#!/bin/bash

read -r -d '' CODE <<'EOC'
perl5.5 BEGIN {$ENV{TMPDIR}="/tmp"}; use File::Temp; File::Temp->new()."";
EOC

echo --------
echo $CODE
echo --------

rm -f ./jail/noseccomp
echo $CODE | sudo strace -f -ojail/killed.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./bin/test_eval.pl
touch ./jail/noseccomp
echo $CODE | sudo strace -f -ojail/alive.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./bin/test_eval.pl
rm -f ./jail/noseccomp
