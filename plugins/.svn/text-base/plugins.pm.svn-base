package Bot::BB3::Plugin::Plugins;
use strict;
sub new {
	my($class) = @_;
	my $self = bless {}, $class;
	$self->{"name"} = "plugins";
	$self->{"opts"}->{"command"} = 1;

	return $self;
}

sub command {
	my($self, $said, $manager) = @_;
	my $output = join(" ", sort map { $_->{name} } @{$manager->get_plugins});
	
	#return( "handled", $output );
	return( "handled", $output );
}

"Bot::BB3::Plugin::Plugins";

__DATA__
Returns a list of all of the loaded plugins for this bot. Syntax, plugins
