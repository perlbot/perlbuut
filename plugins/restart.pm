no warnings 'void';
sub {
	my( $said, $pm ) = @_;

	push @{$said->{special_commands}}, [ bb3_restart=> 1 ];

	print "Attempting to restart..";
}

__DATA__
restart. Attempts to rexecute the bot in the exact manner it was first execute. This has the effect of reloading all config files and associated plugins. Typically root only.
