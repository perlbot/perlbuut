package Bot::BB3::Plugin::Spell;
use Text::Aspell;
use strict;

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'spell';
	$self->{opts} = {
		command => 1,
		handler => 1,
	};

	return $self;
}

sub handle {
	my( $self, $said, $pm ) = @_;

	my( undef, $ret ) = $self->_speller( $said, $pm, 'handle' );
	# TODO fix this, we just get rid of 'handled'.
	# Need to clean up this code to remove this.

	return $ret;
}

sub command {
	my( $self, $said, $pm ) = @_;

	return $self->_speller( $said, $pm, 'command' );
}

sub _speller {
	my( $self, $said, $pm, $type ) = @_;

	my $speller = Text::Aspell->new
		or die "Couldn't create a speller!";
	$speller->set_option('lang','en_GB');

	my $word;

	if( $type eq 'command' ) { #Command Mode
		$word = $said->{recommended_args}->[0];
	}
	else { #Text Search Mode
		if( $said->{body} =~ /(\w+)\s*\(sp\??\)/ ) {
			$word = $1;
		}
	}

	if( $word ) {
		if( $speller->check($word) ) {
			return( 'handled', "$word seems to be correct!" );
		}
		else {
			return( 'handled', "$word seems to be misspelt, perhaps you meant: " . join " ", $speller->suggest( $word ) );
		}
	}

	return;
}

"Bot::BB3::Plugin::Spell";

__DATA__
Attempt to determine the correct spelling of a word. Operates in two modes, addressed, via the syntax spell word; or in passing when you use the string '(sp?)', without the quotes, after any word in any sentence.
