package Bot::BB3::Plugin::Badfacts;
use strict;
no warnings 'void';

use Data::Dumper;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = 'badfacts';
	$self->{opts} = {
		handler => 1,
	};

	return $self;
}

sub handle {
    my ($self, $said, $pm) = @_;

    if ($said->{body} =~ /^!(?<fact>[^@].*?)(?:\s@\s*(?<user>\S*))?$/ ||
        $said->{body} =~ /^!@(?<user>\S+)\s+(?<fact>.+)$/) {
        my $fact = $+{fact};
        my $user = $+{user};
        
        my ($s, $r) = runfacts($fact, $said, $pm);
        if ($s) {
            $r = "$user: $r" if $user;
            $r = "\0".$r;
            return ($r, 'handled');
        }
    }

    return;
}

sub runfacts {
	my( $body, $_said, $pm ) = @_;
    
    my $said = {%$_said};

	my $plugin = $pm->get_plugin( 'fact' );

	$said->{body} = $body;
	$said->{recommended_args} = [ split /\s+/, $body ];
	$said->{command_match} = 'fact';
    $said->{addressed} = 1;

	local $@;
	my( $status, $results ) = eval { $plugin->command( $said, $pm ) };
    my $err = $@;

    warn $err if $err;

	if( $err ) { return( 0, "Failed to execute plugin: facts because $err" ); }
	else { return( 1, $results ) }
}

"Bot::BB3::Plugin::Badfacts";

__DATA__
Supports calling factoids outside of addressed commands using special syntax.  Contact simcop2387 to ask about having it enabled for your channel.
