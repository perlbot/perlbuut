package Bot::BB3::Logger;
use strict;
use Term::ANSIColor qw/:constants/;

sub import {
	my( $class ) = @_;

	my $calling_package = caller;

	no strict;

	for( qw/debug log warn error/ ) {
		*{"${calling_package}::$_"} = \&$_;
	}
}

# goto &foo; automatically calls foo and passes it @_. 
# it also removes the current subroutine from the callstack
# and yes I mostly do it for amusment.

sub debug {
	unshift @_, 'debug';
	goto &write_message;
}

sub log {
	unshift @_, 'log';
	goto &write_message;
}

sub warn {
	unshift @_, 'warn';
	goto &write_message;
}

sub error {
	unshift @_, 'error';
	goto &write_message;
}


my %COLOR_MAP = (
	error => RED,
	warn => YELLOW,
	log => CYAN,
	debug => MAGENTA,
);

sub write_message {
	my( $level, @message ) = @_;
	my( $package, $filename, $line, $sub ) = caller(1); # Ignore the rest of the args
	my $message = "@message";

	$sub =~ s/^${package}:://;

	my $level_color = $COLOR_MAP{$level};
	my $reset = RESET;
	my $white = WHITE; # This is actually sort of gray..
	
	# Default output
	print STDERR "[$level_color$level$reset] $white$package - $line - $sub$reset: $message\n";
}

1;
