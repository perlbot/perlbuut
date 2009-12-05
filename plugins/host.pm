#!/usr/bin/perl
use Net::DNS;
use strict;
use Data::Dumper;

my $foo=sub {
	my( $said, $pm ) = @_;
	my $host = $said->{recommended_args}->[0];
	my $recordtype = $said->{recommended_args}->[1];

	print "Couldn't find a host to check!" and return
		unless $host;

	$recordtype ||= "A";	

  	my $res   = Net::DNS::Resolver->new;
	my $query = $res->query($host, $recordtype);

	if ($query) 
	{
		my @resu;
		foreach my $rr ($query->answer) 
		{
          		next unless $rr->type eq $recordtype;
          		push @resu, $rr->string;
		}
		print "No $recordtype record found for $host" and return if (!@resu);
		s/\s+/ /g for @resu;
		print join(" :: ", @resu) and return;
	} 
	else 
	{
      		print "query failed: ", $res->errorstring;
	}
};

if ($0 =~ /host.pm$/)
{
  $foo->({recommended_args=>['google.com','A']});
}
else
{
  $foo;
}

__DATA__
Returns information about a host's DNS records
