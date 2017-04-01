#!/bin/bash

read -r -d '' CODE <<'EOC'
perl print "Hello"; exec('perl5/perlbrew/perls/perl-5.10.0/bin/perl', "-e", "print 1")
EOC

echo --------
echo $CODE
echo --------

rm -f ./jail/noseccomp
echo $CODE | sudo strace -ojail/killed.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./lib/eval.pl
touch ./jail/noseccomp
echo $CODE | sudo strace -ojail/alive.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./lib/eval.pl
rm -f ./jail/noseccomp
