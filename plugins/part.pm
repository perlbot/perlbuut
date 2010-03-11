no warnings 'void';
sub {
	my( $said, $pm ) = @_;

	push @{$said->{special_commands}},
		map { [ pci_part => $_ ] } @{$said->{recommended_args}}
	;

	print "Attempting to leave: @{$said->{recommended_args}} ";
}

__DATA__
Attempts to leave a list of channels. Syntax, part #foo #bar #baz. Note, does no sanity checking. Typically requires op or superuser.
