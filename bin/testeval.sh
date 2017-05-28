#!/bin/bash

read -r -d '' CODE <<'EOC'
perl
use strict;
use warnings;

use Test::More;
use Test::Deep qw(:v1 cmp_details deep_diag);

{
    package ClassA;

    sub new { bless {}, shift }

    sub values {
        foo => 1,
        bar => 2,
        baz => 3,
    }
}

my $obj = ClassA->new;

cmp_deeply $obj, listmethods(
    values => code(sub {
        my ($it) = @_;
        my ($ok, $stack) = cmp_details { @$it }, {
            foo => 1,
            bar => 2,
            baz => 3,
        };
        $ok || (0, deep_diag $stack)
    }),
);

done_testing;
EOC

echo --------
echo $CODE
echo --------

echo $CODE | sudo strace -f -o killed.log timeout 30 /home/ryan/perl5/perlbrew/perls/perlbot-inuse/bin/perl5* ./bin/test_eval.pl
