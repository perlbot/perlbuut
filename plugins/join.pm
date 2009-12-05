sub {
	my( $said, $pm ) = @_;

	my @channels = grep /^#/, @{ $said->{recommended_args} };

	push @{ $said->{special_commands} },   
		[ 'pci_join', @channels ];

	print "Joining @{ $said->{recommended_args} }";
}

__DATA__
Attempts to join a list of channels. Syntax join #foo #bar #baz. Typically requires op or superuser.
