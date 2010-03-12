no warnings 'void';
sub {
	my( $said, $pm ) = @_;

	push @{ $said->{special_commands} },
		[ pm_reload_plugins => 1 ]
	;

	print "Attempting to reload plugins...";
}

__DATA__

Attempts to reload all of the plugins in the plugin directory. Has the effect of reloading any changed plugins or adding any new ones that have been added. Typically root only.
