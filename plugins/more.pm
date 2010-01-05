package Bot::BB3::Plugin::More;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = 'more';
	$self->{opts} = {
		command => 1,
		post_process => 1,
	};

	return $self;
}

sub initialize {
	my( $self, $pm, $cache ) = @_;

	$self->{cache} = $cache;
}

sub command {
	my( $self, $said, $pm ) = @_;

	my $text = $self->{cache}->get( "pager_$said->{name}" );
	$self->{cache}->remove( "pager_$said->{name}" );

	if( $text ) { return( 'handled', "...$text" ); }
	else { return( 'handled', "Sorry, no more output" ); }
}

sub post_process {
	my( $self, $said, $pm, $output_ref ) = @_;

	return if $said->{channel} =~ /^\*/;

	# Magic numbers are awesome.
	# the usual max length for an irc message is around 425?
	# Something like that.

	# The actual max is usually 512 but you need room for nicks and command types.
	if( length $$output_ref > 400 ) {

		# Sanity checking, let's not store novels. yes lets
#		if( length $$output_ref > 1_000 ) { 
#			my $new_out = $$output_ref = substr( $$output_ref, 0, 1_000 ); 
#			$$output_ref = $new_out;
#
#			warn "Sanity checking, new length: ", length $$output_ref;
#		}

		my $new_text = substr( $$output_ref, 0, 350, '' );

		$self->{cache}->set( "pager_$said->{name}", $$output_ref, "10 minutes" ); #Remainder

		$$output_ref = $new_text;
		$$output_ref .= "... [Output truncated. Use `more` to read more]";
	}
}

"Bot::BB3::Plugin::More";
__DATA__
More acts as a pager. It automatically truncates output that is too long and saves it in a buffer based on your name. Use the command `more` to access the remainder of the text.
