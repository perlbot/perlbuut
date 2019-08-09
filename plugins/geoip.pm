use GeoIP2::Database::Reader;
use Socket;

use strict;
no warnings 'void', 'once';

sub {
	my( $said, $pm ) = @_;

  my $ip = $said->{body};

  $ip =~ s/#.*//;
  $ip =~ s/^\s+|\s+$//g;

  if ($ip =~ /\D/) {
    my $packed = gethostbyname($ip);
    $ip = inet_ntoa($packed);
  }

  my $reader = GeoIP2::Database::Reader->new(file => '/home/ryan/bots/perlbuut/var/GeoLite2-City.mmdb');
  my $asn_reader = GeoIP2::Database::Reader->new(file => '/home/ryan/bots/perlbuut/var/GeoLite2-ASN.mmdb');

	print "Record for $said->{body}: ";
  my $record = $reader->city(ip => $ip);
  my $asn_record = $asn_reader->asn(ip => $ip);

  my $subdiv = eval {($record->subdivisions)[0]->name};

  my $location = join(', ', grep {!!$_} ($record->city->name, $subdiv, $record->country->name));

  print $location, " ASN: ", $asn_record->autonomous_system_organization, "(", $asn_record->autonomous_system_number, ")";
};

__DATA__
geoip 192.168.32.45 or geoip example.com; returns the country associated with the resolved IP address.
