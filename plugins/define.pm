package Bot::BB3::Plugin::Define;
use Net::Dict;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'define';
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;
	my $word = $said->{recommended_args}->[0];

	# Note that our cache only lasts for our
	# plugin handler's life. Oh well.
	return $self->{cache}->{$word}
		if defined $self->{cache}->{$word};

	my $dict = Net::Dict->new('dict.org');
	$dict->setDicts( 'wn', 'web1913' );

	my $defs = $dict->define( $word  );
	my $definition = $defs->[0]->[1];
		$definition =~ s/[ \t\n]+/ /g;

	if( $definition ) {
		$self->{cache}->{$word} = $definition;

		return( 'handled', $definition );
	}
	else {
		return( 'handled', 'Whups, no definition for you' );
	}
}

"Bot::BB3::Plugin::Define";

__DATA__
Attempts to find a definition for a given term. Syntax, define TERM.
