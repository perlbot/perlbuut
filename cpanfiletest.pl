use strict;
use warnings;

use Module::CPANfile;
use Data::Dumper;

my $file = Module::CPANfile->load("/home/ryan/bots/perlbuut/cpanfile");

my $prereqs = $file->prereqs;

my @phases = $prereqs->phases;
my @prereqs;

for my $phase (@phases) {
  # TODO try/catch and check other types
  for my $type (qw/requires recommends/) {
    push @prereqs, $prereqs->requirements_for($phase, $type)->required_modules;
  }
}

# TODO uniq

print Dumper(\@prereqs);
