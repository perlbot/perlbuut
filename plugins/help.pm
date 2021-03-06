use strict;

no warnings 'void';

sub {
	my( $said, $pm ) = @_;

	my $plugin_name = $said->{recommended_args}->[0];

	if( length $plugin_name ) {
		my $plugin = $pm->get_plugin( $plugin_name, $said );

		if( $plugin ) {
      if ($plugin->can("make_help")) {
        print $plugin->make_help();
      } else {
  			print $plugin->{help_text};
      }
		}
		else {
			print "Sorry, no plugin named $plugin_name found." unless $said->{backdressed};
		}
	}
	else {
		print "Provides help text for a specific command. Try 'help echo'. See also the command 'plugins' to list all of the currently loaded plugins.";
	}
};

__DATA__
Attempts to find the help for a plugin. Syntax help PLUGIN. 
