use Data::Dumper;

no warnings 'void';
sub {
	my( $said, $pm ) = @_;
	my $conf = $pm->get_main_conf;
	
	my( $path, $value ) = split " ", $said->{body}, 2;

	my $ref = $conf;

	for( split /\./, $path ) {
		if( ref $ref eq 'HASH' ) {
			$ref = $ref->{$_};
		}
		elsif( ref $ref eq 'ARRAY' ) {
			$ref = $ref->[$_];
		}
		else {
			print "Errored out at $ref";
			return;
		}
	}

	if( not length $ref ) {
		print "Failed to find element for $path; try conf_dump";
		return;
	}
	
	if( not length $value ) {
		if( ref $ref ) {
			$Data::Dumper::Terse = 1;
			print Dumper $ref;
		}
		else {
			print $ref;
		}
		return;
	}

	
	print "Attempting to set [$path] to [$value] - $ref";

	push @{$said->{special_commands}}, [ bb3_change_conf => $path, $value ];

};

__DATA__
conf <string> [new value]. Displays a portion of the conf structure corresponding to the dot seperated string passed to this plugin. For example, the string "bot.0" will display the complete structure of the first bot defined in the config file. Can also be used to set the value by passing a second argument after the location specifier. New values can be either a single string to set a scalar argumnet, or a comma seperated string surrounded by [], such as [foo,bar,baz]. White space around the commas are removed. This argument is turned in to an arrayref, in other words, a multivalued argument for the config option specified.


