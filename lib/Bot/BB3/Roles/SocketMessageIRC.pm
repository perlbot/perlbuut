package Bot::BB3::Roles::SocketMessageIRC;

use POE;
use POE::Wheel::SocketFactory;
use POE::Wheel::ReadWrite;
use Socket;
use strict;

sub new {
	my( $class, $conf, $pm ) = @_;

	my $self = bless { conf => $conf }, $class;

	$self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/_start new_connection failed_connection read_line socket_error/ ]
		]
	);


	return $self;
}

sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];

	$kernel->alias_set( __PACKAGE__ );

	$self->{socketfactory} = POE::Wheel::SocketFactory->new(
		BindAddress => '127.0.0.1',
		BindPort => ( $self->{conf}->{roles}->{socketmessageirc}->{port} || 10090 ),
		SocketDomain => AF_INET(),
		SocketType => SOCK_STREAM(),
		SocketProtocol => 'tcp',
		ListenQueue => 50,
		Reuse => 'on',

		SuccessEvent => 'new_connection',
		FailureEvent => 'failed_connection',
	);

}

sub new_connection {
	my( $self, $socket ) = @_[OBJECT,ARG0];

	my $wheel = POE::Wheel::ReadWrite->new(
		Handle => $socket,
		Driver => POE::Driver::SysRW->new,
		Filter => POE::Filter::Line->new,

		InputEvent => "read_line",
		ErrorEvent => "socket_error",
	);

	$self->{rw_wheels}->{$wheel->ID} = $wheel; # save our reference
}

sub failed_connection {
}

sub read_line {
	my( $self, $kernel, $line ) = @_[OBJECT,KERNEL,ARG0];

	my( $server, $nick, $channel, $message ) = split/\s*:\s*/, $line, 4;

	warn "Receiving irc message: $server,$nick,$channel,$message\n";

	$kernel->post( 
		"Bot::BB3::Roles::IRC", 
		'external_message',
		$server,
		$nick,
		$channel,
		$message
	);

}

sub socket_error {
	my( $self, $wheel_id ) = @_[OBJECT,ARG3];

	delete $self->{rw_wheels}->{$wheel_id};
}

1;
