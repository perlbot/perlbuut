package Bot::BB3::Plugin::BadfactsTemp;
use strict;
no warnings 'void';

use Data::Dumper;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = 'badfactstemp';
	$self->{opts} = {
		handler => 1,
        command => 1,
	};

	return $self;
}

sub command {
    my ($self, $said, $pm) = @_;

    # Always require this to be addressed, regardless of plugin config
    if ($said->{addressed}) {
        my $body = $said->{body};
        
        if ($body =~ /^#(?<channel>\S+)\s+(?:(?<command>forget|learn|relearn|literal|revert|revisions|search|protect|unprotect|substitue|macro)\s+)?(?<fact>.*?)$/) {
            my ($command, $channel, $fact) = @+{qw/command channel fact/};

            my $realfact = ($command?"$command ":"")."__${channel}_$fact";

            return ('handled', $realfact);
        } else {
            return ('handled', "helptexthere");
        }
    }

    return;
}

sub handle {
    my ($self, $said, $pm) = @_;

    if ($said->{body} =~ /^!(?<fact>[^@].*?)(?:\s@\s*(?<user>\S*))?$/ ||
        $said->{body} =~ /^!@(?<user>\S+)\s+(?<fact>.+)$/) {
        my $fact = $+{fact};
        my $user = $+{user};

        # TODO HACK XXX bad hack to prevent noise until better way is decided
        return ('', 'handled') if $fact =~ /^regex\s/;

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

"Bot::BB3::Plugin::BadfactsTemp";

__DATA__
Supports calling factoids outside of addressed commands using special syntax.  Contact simcop2387 to ask about having it enabled for your channel.
