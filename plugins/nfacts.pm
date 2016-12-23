package Bot::BB3::Plugin::NFacts;
use strict;
no warnings 'void';

use Data::Dumper;

our $pname = "nfacts";
my $fsep = "\034"; # ASCII file seperator

sub get_conf_for_channel {
    my ($self, $pm, $server, $channel) = @_;
    my $conf = $pm->plugin_conf($pname, $server, $channel);
    return $conf;
}

sub namespace_factoid {
    my ($self, $pm, $body, $said, $forcechan, $forceserver) = @_;
    
    my ($channel, $server) = @{$said}{qw/channel server/};
    $server =~ s/^.*?([^.]+\.(?:com|net|co.uk|org|bot|info))$/$1/; # grab just the domain and tld, will expand to more domains later
    
    $channel = $forcechan   // $channel;
    $server  = $forceserver // $server;
    
    warn "NAMESPACE: [ $channel , $server ]";
    
    my $conf = $self->get_conf_for_channel($pm, $said->{server}, $channel);
    
    warn Dumper($conf);
    
    my $realserver = $conf->{serverspace} // $server;
    my $realchannel = $conf->{chanspace}  // $channel;
    
    if ($body =~ /^(?:(?<command>forget|learn|relearn|literal|revert|revisions|search|protect|unprotect|substitue|macro)\s+)?(?<fact>.*?)$/) {
        my ($command, $fact) = @+{qw/command fact/};
        $body = "${command} ${fsep}${realserver}${fsep}${realchannel}${fsep}${fact}";
    } else {
        $body = "${fsep}${realserver}${fsep}${realchannel}${fsep}${body}";
    }
    
    return $body;
}

sub namespace_filter {
    my ($body, $enabled) = @_;
    
    return $body =~ s|$fsep.*?$fsep.*?$fsep(\S+)(?=\s)|$1|rg if $enabled;
    $body;
}

sub new {
    my( $class ) = @_;
    my $self = bless {}, $class;
    $self->{name} = $pname;
    $self->{opts} = {
        handler => 1,
        command => 1,
    };

    return $self;
}

sub command {
    my ($self, $_said, $pm) = @_;
    my $said = {%$_said}; # copy it so we can mutate it later
    my $conf = $self->get_conf_for_channel($pm, $said->{server}, $said->{channel});
    
    # Always require this to be addressed, regardless of plugin config
    if ($said->{addressed}) {
        my $body = $said->{body};
        
        $body =~ s/^\s*$pname\s*//;
        $body =~ s/^\s+|\s+$//g;
        
        if ($body =~ /^(?<channel>#\S+)\s+(?<fact>.*)$/) {
            my ($channel, $fact) = @+{qw/channel fact/};
            
            $said->{channel} = $channel;
            my ($status, $result) = $self->runfacts($fact, $said, $pm, $conf);
            return ('handled', $result);
        } else {
            my ($status, $result) = $self->runfacts($body, $said, $pm, $conf);
            return ('handled', $result);
        }
    }

    return;
}

sub handle {
    my ($self, $said, $pm) = @_;
    my $conf = $self->get_conf_for_channel($pm, $said->{server}, $said->{channel});
    
    return unless $conf->{enabled};

    my $prefix = $conf->{prefix} || "!";
    
    my $regex = qr/^\Q$prefix\E(?<fact>[^@].*?)(?:\s@\s*(?<user>\S*)\s*)?$/;

    if ($said->{body} =~ /^\Q$prefix\E(?<fact>[^@].*?)(?:\s@\s*(?<user>\S*)\s*)?$/ ||
        $said->{body} =~ /^\Q$prefix\E!@(?<user>\S+)\s+(?<fact>.+)$/) {
        my $fact = $+{fact};
        my $user = $+{user};
        
#        return (Dumper($said), "handled");

        my ($s, $r) = $self->runfacts($fact, $said, $pm, $conf);
        if ($s) {
            $r = "$user: $r" if $user;
            $r = "\0".$r;
            return ($r, 'handled');
        }
    }

    return;
}

sub runfacts {
    my( $self, $body, $_said, $pm, $conf, $server, $channel ) = @_;
    
    my $said = {%$_said};
    my @suggests;
    
    my $plugin = $pm->get_plugin( 'fact' );

    $said->{body} = $self->namespace_factoid($pm, $body, $said, $channel, $server);
    $said->{recommended_args} = [ split /\s+/, $said->{body} ];
    $said->{command_match} = 'fact';
    $said->{nolearn} = !($_said->{addressed}); # Only learn if we were addressed originally
    $said->{addressed} = 1;
    $said->{backdressed} = 1;
    
    local $@;
    my( $status, $results ) = eval { $plugin->command( $said, $pm ) };
    my $err = $@;
    
    push @suggests, @{$said->{metaphone_matches} // []};
   
    if ($err || !$status || !defined($results)) {
        $said->{body} = $body;
        $said->{recommended_args} = [ split /\s+/, $said->{body} ];
        $said->{nolearn} = 1; # never learn a global this way
        delete $said->{metaphone_matches};
        
        ( $status, $results ) = eval { $plugin->command( $said, $pm ) };
        $err = $@;
        
        push @suggests, @{$said->{metaphone_matches} // []};
    }
    
    warn $err if $err;
    
    if( $err ) { 
        return( 0, "Failed to execute plugin: facts because $err" ); 
    } else { 
        if (!$status && !$results) {
            # Do suggests from here to cross namespaces
            #return( 1, "[" . join(", ", @suggests) . "]" );
            return(1, "");
        } else {
            return( 1, namespace_filter($results, $conf->{filtersep}) );
        } 
    }
}

"Bot::BB3::Plugin::NFacts";

__DATA__
nfacts [#channel] <factoid command> - Use/set a factoid for/from a channel on this server.
Also supports calling factoids outside of addressed commands using special syntax.  Contact simcop2387 to ask about having it enabled for your channel.
