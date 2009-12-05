use Geo::WeatherNWS;
use Weather::Underground;
use Data::Dumper;
use Geo::IATA;
use List::AllUtils qw/first/;


# Stefan Petrea
# stefan.petrea at gmail.com
# perlhobby.googlecode.com


my $solve_weather = sub {
    my $arg = shift;
    my $g = Geo::IATA->new;
    my $location = first { defined $_->{icao} } @{$g->location($arg)};
    my $weather = Weather::Underground->new( place => $location->{icao}, debug => 0 );
    my $data = $weather->get_weather;

    return ($weather,$data,$location->{location});
};



sub {
	my( $said, $pm ) = @_;
	my $arg = $said->{body};
	s/^\s+//,s/\s+$// for $arg;

	if( $arg =~ /^[kK]/ or $arg =~ /^\w{3}$/ ) {
		my $w= Geo::WeatherNWS->new;
		$w->getreporthttp( $arg );

		print "$w->{code}: $w->{temperature_f} degrees, $w->{conditionstext} with a windchill of $w->{windchill_f}f and winds up to $w->{windspeedmph}mph";
	}
	else {
		my $weather = Weather::Underground->new( place => $arg, debug => 0 );
		my $data = $weather->get_weather;

		my $resolved_location = "";
		($weather,$data,$resolved_location) = $solve_weather->($arg) unless $data; # fix it if we have a problem

		if( not $data or not @$data ) {
			print "Failed to find weather for $arg";
			return;
		};


		$data = $data->[0]; # We want the first one..

		my $where = 
		$resolved_location 
			? "Resolved location->{$resolved_location}: "
			: "$arg:";

		print "$where $data->{temperature_fahrenheit} degrees, $data->{conditions} and winds up to $data->{wind_milesperhour}";
	}
}


__DATA__
weather <zipcode> or weather <airport code>; attempts to retrieve the weather from a station associated with one of the names you pass it.
