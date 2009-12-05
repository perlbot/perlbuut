package Bot::BB3::ConfigParser;
use Config::General;
use Bot::BB3::Logger;
use strict;

sub parse_file {
	my( $class, $file ) = @_;
	
	my $conf = {
		Bot::BB3::ConfigParser->get_cg_object($file)->getall
	};

	# This is attempting to distinguish between the options such as:
	# <bot MyBotName> </bot>
	# and <bot> botname MyBotName </bot>
	# type configurations also it handles either multiple
	# bots or a single bot. Stupid config general.
	# The ->botname bit is a check to make sure we're not dealing with
	# a single <bot></bot> defined.
	if( $conf->{bot} and ref $conf->{bot} eq 'HASH' and not $conf->{bot}->{botname} ) { 
		my $bots = $conf->{bot};

		my @connections;
		while( my( $botname, $options ) = each %$bots )
		{
			# More attempts at making Config::General behave itself.
			next unless ref $options;

			for my $options ( ref $options eq 'ARRAY' ? @$options : $options )
			{   
				$options->{botname} = $botname;
				push @connections, $options;
			}   
		}

		$conf->{bot} = \@connections;
	}
	# Again, specifically dealing with <bot></bot> thingy. SIGH.
	elsif( $conf->{bot}->{botname} ) {
		$conf->{bot} = [ $conf->{bot} ];
	}

	return $conf;

}

sub save_file {
	my( $class, $filename, $conf ) = @_;
	my $obj = Bot::BB3::ConfigParser->get_cg_object;

	# Note that we tend to lose comments doing this..
	$obj->save_file( $filename, $conf );
}

sub get_cg_object {
	my( $class, $file ) = @_;

	return Config::General->new(
		-ConfigFile => $file,
		-LowerCaseNames => 1,
		-UseApacheInclude => 1,
		-AutoTrue => 1
	);
}

1;
