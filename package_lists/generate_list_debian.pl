#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use v5.20.0;

use Data::Dumper;
use LWP::Simple;
use HTML::TreeBuilder::XPath;

open(my $fh, "-|", "apt-cache", "dumpavail");

my @packs; 
my $p;
while(<$fh>) {
    if (/^\s*$/) {
        push @packs, $p; $p=""
    } else {
        $p.=$_;
    } 
}; 
    
@packs = map {/Package:\s*(?<package>\S+).*?Homepage:\s*(?<url>\S+)/si; ["debian", $+{package}, $+{url}];} grep {$_ =~ /search.cpan.org/} @packs; 

my @modules;
#print Dumper(\@packs);

for my $pack (@packs) {
#    my @m = map {s|^lib/||; s|/|::|g; s|\.pm$||; $_} map {/>\s*([^<>]+)\s*</; $1} grep {/\.pm/} split(/\n/, get($pack->[2].'/MANIFEST'));
    my $xp = HTML::TreeBuilder::XPath->new_from_content( get($pack->[2]) );

    my @m = grep {/[A-Z]/} map {s|^lib/||; s|/|::|g; s|\.pm$||; $_} map {s/^\s*|\s*$//gr} $xp->findvalues( "//table[preceding::h2[text()='Modules']]/tr/td[1]" );

    say '"'.$pack->[0].'","'.$pack->[1].'","'.$_.'"' for @m;
}
