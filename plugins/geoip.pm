use Geo::IP;

no warnings 'void', 'once';

sub {
	my( $said, $pm ) = @_;
#        $Geo::IP::PP_OPEN_TYPE_PATH = "/usr/share/GeoIP/";
#	my $gi = Geo::IP->open_type(GEOIP_CITY_EDITION_REV0, GEOIP_STANDARD);
        my $gi = Geo::IP->open("/usr/share/GeoIP/GeoIP.dat", GEOIP_STANDARD);


	print "Record for $said->{body}: ";

	if( $said->{body} =~ /[a-zA-Z]/ ) {
		print $gi->country_code_by_name( $said->{body} );
	}
	else {
		print $gi->country_code_by_addr( $said->{body} );
	}
};

__DATA__
geoip 192.168.32.45 or geoip example.com; returns the country associated with the resolved IP address.
