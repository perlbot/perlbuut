package Bot::BB3::Plugin::Default;
use strict;
no warnings 'void';

use Data::Dumper;

our $pname = "default";

sub get_conf_for_channel {
    my ($self, $pm, $server, $channel) = @_;
    my $conf = $pm->plugin_conf($pname, $server, $channel);
    return $conf;
}

sub new {
    my( $class ) = @_;
    my $self = bless {}, $class;
    $self->{name} = $pname;
    $self->{opts} = {
        command => 1,
    };

    return $self;
}

sub command {
    my ($self, $_said, $pm) = @_;
    my $said = {%$_said}; # copy it so we can mutate it later
    my $conf = $self->get_conf_for_channel($pm, $said->{server}, $said->{channel});

    if ($said->{addressed}) {
        my $plug_name = $conf->{plugin} // 'fact';
        my $plugin = $pm->get_plugin( $plug_name );

        $said->{body} =~ s/^default //g;
        $said->{recommended_args} = [ split /\s+/, $said->{body} ];

        local $@;
        my( $status, $results ) = eval { $plugin->command( $said, $pm ) };
        my $err = $@;

        return ($status, $results);
    }

    return;
}

"Bot::BB3::Plugin::Default";

__DATA__
default plugin handler that supports per channel configurations
