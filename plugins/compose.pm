package Bot::BB3::Plugin::Compose;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = 'compose';
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;

	my $results = compose( $said, $pm );

	return('handled', $results);
}

# compose($body) does the main part of the composing,
# it should be in a module so both compose and factoid can call it.
# The calls should be wrapped around for security and stuff.

sub compose {
	my($said, $pm) = @_;
	my $str = $said->{body};

	$str =~ /\A\s*((\S).*(\S))\s*\z/s or
		return "Error: empty expression for compose";
	my($expr, $openmark, $closemark) = ($1, $2, $3);
	$openmark ne $closemark or
		return "Error: identical open and close bracket marks for compose";

	# we do things in two pass so we don't call any plugins if there are unbalanced parenthesis
	my @toke;
	my $depth = 0; my $finished = 0;
	while ($expr =~ /\G(.*?)(?:(\Q$openmark\E)|\Q$closemark\E)/sg) {
		my($part, $open) = ($1, defined($2));
		$finished and
			return "Error: unmatched closing parenthesis in compose";
		push @toke, ["part", $part];
		if ($open) {
			push @toke, ["open"];
			$depth++;
		} else {
			0 < --$depth or
				$finished = 1;
			0 <= $depth or
				die "internal error: uncaught unmatched closing parenthesis in compose";
			push @toke, ["close"];
		}
	}
	0 == $depth or
		return "Error: unmatched opening parenthesis in compose";

	my @stack = ("");
	for my $toke (@toke) {
		my($op, $val) = @$toke;
		if ("part" eq $op) {
			$stack[-1] .= $val;
		} elsif ("open" eq $op) {
			push @stack, "";
		} elsif ("close" eq $op) {
			my $cmd = pop @stack;
			#warn "cmd=|$cmd|";
			my($success, $res) = runplugin($cmd, $said, $pm, 1 < @stack);
			#warn "res=|$res|";
			$success or
				return $res;
			$stack[-1] .= $res;
		} else {
			die "internal error: tokenizer found invalid token in compose";
		}
	}

	1 == @stack or
		die "internal error: execution stack unbalanced but the parenthesis were balanced in compose";
	return $stack[0];

}

sub runplugin {
	my( $cmd_string, $said, $pm, $captured ) = @_;
	my( $cmd, $body ) = split " ", $cmd_string, 2;
	defined($cmd) or
		return( 0, "Error, cannot parse call to find command name, probably empty call in compose" );
	defined($body) or $body = "";
	
	my $plugin = $pm->get_plugin( $cmd, $said )
		or return( 0, "Compose failed to find a plugin named: $cmd" );

	local $said->{body} = $body;
	local $said->{recommended_args} = [ split /\s+/, $body ];
	local $said->{command_match} = $cmd;

	local $said->{nested} = 1; # everything called through compose is nested,
	$captured and local $said->{captured} = 1; 
		# but things called on top-level of compose are captured only if the compose itself is captured
	
	local $@;
	my( $status, $results ) = eval { $plugin->command( $said, $pm ) };

	if( $@ ) { return( 0, "Failed to execute plugin: $cmd because $@" ); }

	else { return( 1, $results ) }

	return( 0, "Error, should never reach here" );
}


1 #"Bot::BB3::Plugin::Compose";

__DATA__
Supports composing multiple plugins together. That is, it allows you to feed the output of one plugin to another plugin. Syntax compose (eval (echo 2+2)). Note that it uses the first non whitespace character as the start-delimiter and the last non-whitespace as the end delimter.
