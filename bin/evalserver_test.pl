
use POE::Filter::Reference;
use IO::Socket::INET;
use Data::Dumper;


my $filter = POE::Filter::Reference->new();

while( 1 ) {
	print "Code: ";
	my $code = <STDIN>;

	my $socket = IO::Socket::INET->new(  PeerAddr => 'simcop2387.info', PeerPort => '14400' );
	my $refs = $filter->put( [ { code => "$code" } ] );

	print $socket $refs->[0];

	local $/;
	my $output = <$socket>;
	print "OUTPUT: ", Dumper($filter->get( [ $output ] )), "\n";

	$socket->close;
}
