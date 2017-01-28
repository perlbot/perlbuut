#!/bin/bash

read -r -d '' CODE <<'EOC'
perl $SIG{SEGV}="ignore"; $q=unpack "p*", 0xdeadbeef; "DEADBEEF"
EOC

echo --------
echo $CODE
echo --------

rm -f ./jail/noseccomp
echo $CODE | sudo strace -ojail/killed.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./lib/eval.pl
touch ./jail/noseccomp
echo $CODE | sudo strace -ojail/alive.log /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./lib/eval.pl
rm -f ./jail/noseccomp
