use Config::General;

no warnings 'void';

sub {
	my( $said, $pm ) = @_;
	my $main_conf = $pm->get_main_conf;

    my $o;
    {no warnings 'once'; #keep it from bitching about it
	$o = Config::General->new(
			-ConfigFile => $file,
			-LowerCaseNames => 1,
			-UseApacheInclude => 1,
			-AutoTrue => 1
		);
    }
    
	print $o->save_string( $main_conf );
};

__DATA__

Dump the current configuration file
