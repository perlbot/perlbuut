#!/bin/bash

read -r -d '' CODE <<'EOC'
perl use IO::Async::Loop; my $loop = IO::Async::Loop->really_new; my $foo; $loop->timeout_future(after => 1.5)->on_done(sub { $foo = 42 })->get; $foo
EOC

echo --------
echo $CODE
echo --------

rm -f ./jail/noseccomp
echo $CODE | sudo strace -okilled.log /home/ryan/perl5/perlbrew/perls/perl-blead/bin/perl ./lib/eval.pl
touch ./jail/noseccomp
echo $CODE | sudo strace -oalive.log /home/ryan/perl5/perlbrew/perls/perl-blead/bin/perl ./lib/eval.pl
rm -f ./jail/noseccomp
