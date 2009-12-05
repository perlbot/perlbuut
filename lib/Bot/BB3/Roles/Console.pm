package Bot::BB3::Roles::Console;
use POE;
use POE::Session;
use POE::Wheel::SocketFactory;
use strict;

use Bot::BB3::Logger;

sub new {
	my( $class, $conf, $pm ) = @_;
	
	my $self = bless { conf => $conf, pm => $pm }, $class;

	$self->spawn_session;

	return $self;
}

sub spawn_session {
	my( $self ) = @_;

	$self->{session} = POE::Session->create(
		object_states => [ 
			$self => [ 
				qw/_start 
				socket_new factory_fail 
				socket_read socket_write plugin_output/
			]
		]
	);

	return $self;
}

sub _start {
	my( $self ) = @_[OBJECT];

	$self->{socket_factory} = POE::Wheel::SocketFactory->new(
		BindAddress => "127.0.0.1",
		BindPort => $self->{conf}->{roles}->{console}->{port} || 10041,
		SuccessEvent => 'socket_new',
		FailureEvent => 'factory_fail',
		Reuse => 'on',
	);
}

sub socket_new {
	my( $self, $handle ) = @_[OBJECT,ARG0];

	warn "Got a socket: $handle\n";

	my $wheel = POE::Wheel::ReadWrite->new(
		Handle => $handle,
		Driver => POE::Driver::SysRW->new,
		
		InputFilter => POE::Filter::Line->new,
		OutputFilter => POE::Filter::Stream->new,

		InputEvent => 'socket_read',
		FlushedEvent => 'socket_write',
		ErrorEvent => 'socket_error',
	);

	$self->{wheels}->{$wheel->ID} = $wheel;
}

sub socket_error {
	my( $self, $op, $errstr, $errnum, $id ) = @_[OBJECT,ARG0..ARG3];

	#TODO figure out which errors we don't care about.
	warn "Socket Error: $op - $errstr - $errnum\n";
	delete $self->{wheels}->{$id};
}

sub factory_fail {
	my( $self, $op, $errstr, $errnum, $id ) = @_[OBJECT,ARG0..ARG3];

	warn "Help, I'm falling! $op - $errstr $errnum";

	#Attempt a respawn
	delete $self->{session};
	# TODO look for ways to stop a session?
	$self->spawn_session;
}

sub socket_write { 
	my( $self, $id ) = @_[OBJECT,ARG0];

	warn "Written some data to $id\n";
}

sub socket_read {
	my( $self, $input, $id ) = @_[OBJECT,ARG0,ARG1];

	#$input is a line containing a command
	s/^\s+//,s/\s+$// for $input;
	my( $command, @args ) = split /\s+/, $input;

	# Command disabled since we don't have access
	# to that object any more.
	my %special_commands = (
		#'list_pcis' => sub { 
			#my $ic=$self->{parent}->{irc_components};
			
			#for( keys %$ic ) {
				#$self->{wheels}->{$id}->put(  "$_: " . $ic->{$_}->server_name . "\n" );
			#}
		#},
	);

	if( exists $special_commands{$command} ) {
		$special_commands{$command}->();
	}
	else {

		my $said = {
			body => $input,
			raw_body => $input,
			my_name => 'CommandConsole',
			addressed => 1,
			recommended_args => \@args,
			channel => '*special',
			name => 'CC',
			ircname => 'CC',
			host => '*special',
			server => '*special',
			pci_id => $id,

		};
		
		$self->{pm}->yield( execute_said => $said );
	}
}

sub plugin_output {
	my( $self, $said, $output ) = @_[OBJECT,ARG0,ARG1];
	my $wheel_id = $said->{pci_id};

	$self->{wheels}->{$wheel_id}->put( "$output\n" );
}

1;
