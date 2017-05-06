package EvalServer;

use POE;
use POE::Wheel::SocketFactory;
use POE::Wheel::ReadWrite;
use POE::Filter::Reference;
use POE::Filter::Line;
use POE::Filter::Stream;
use POE::Wheel::Run;
use strict;
use EvalServer::Sandbox;

sub start {
	my( $class ) = @_;

	my $self = $class->new;
	my $session = POE::Session->create(
		object_states => [
			$self => [ qw/
				_start _stop
				socket_new socket_fail socket_read socket_write
				spawn_eval eval_read eval_err eval_close eval_stdin
				dead_child timeout
				/ ],
		]
	);

	POE::Kernel->run();
}

sub new {
	return bless {}, shift;
}

sub spawn_eval {
	my( $self, $kernel, $args, $parent_id ) = @_[OBJECT,KERNEL,ARG0,ARG1];

	my $filename = 'eval.pl';
	if( not -e $filename ) {
		$filename = $FindBin::Bin . "/../lib/$filename";
	}
warn "Spawning Eval: $args->{code}\n";
	my $wheel = POE::Wheel::Run->new(
		Program => \&EvalServer::Sandbox::run_eval,
    ProgramArgs => [ ],

		CloseOnCall => 1, #Make sure all of the filehandles are closed.
		Priority => 10, #Let's be nice!

		StdoutEvent => 'eval_read',
		StderrEvent => 'eval_err',
		StdinEvent => 'eval_stdin',
		CloseEvent => 'eval_close',
		
		StdinFilter => POE::Filter::Line->new,
		StdoutFilter => POE::Filter::Stream->new(),
		StderrFilter => POE::Filter::Stream->new(),
	);

	warn "Storing Eval id: ", $wheel->ID, "\n";
	$self->{ eval_wheels }->{ $wheel->ID } = { wheel => $wheel, parent_id => $parent_id };

	$wheel->put( $args->{code} );

	warn "Adding delay for 30 seconds: ", $wheel->ID;
	$kernel->delay_set( timeout => 30, $wheel->ID );
}


sub timeout {
	my( $self, $wheel_id ) = @_[OBJECT,ARG0];
	warn "Got a timeout idea for $wheel_id";
	my $wheel = $self->{ eval_wheels }->{ $wheel_id }->{ wheel }
		or return; # Our wheel has gone away already.
	
	warn "Trying to kill: ", $wheel->PID;

	kill( 'TERM', $wheel->PID ); # Try to avoid orphaning any sub processes first
  sleep(3);
  kill( 'KILL', $wheel->PID );
}

sub _append_output {
	my $self = shift; #Decrement @_ !
	my( $cur_session, $kernel, $results, $id ) = @_[SESSION,KERNEL,ARG0,ARG1];
	warn "AT UNDERSCORE: @_\n";

	warn "Attempting to append: $self, $results, $id\n";

	#return unless $results =~ /\S/;

	my $output_buffer = $self->{ wheel_outputs }->{ $id } ||= [];

	push @$output_buffer, $results;

	warn "Checking length: ", scalar( @$output_buffer );
	if( @$output_buffer > 1000 ) { # Lets not be silly
		warn "Attempting to force a timeout using $cur_session";
		$kernel->call( $cur_session->ID, timeout => $id ); #Force a timeout. Go away spammy outputs.
		my $wheel = $self->{ eval_wheels }->{ $id }->{ wheel };
		if( $wheel ) { $wheel->pause_stdout };
		$kernel->call( $cur_session->ID, eval_close => $id );
	}
}

sub eval_read {
	#my( $self, $cur_session, $kernel, $results, $id ) = @_[OBJECT,SESSION,KERNEL,ARG0,ARG1];
	my $self  = $_[OBJECT];

	$self->_append_output( @_ );
}

sub eval_err {
	my( $self, $error ) = @_[OBJECT,ARG0];

	$self->_append_output( @_ );
}

sub eval_stdin {
	my( $self, $id ) = @_[OBJECT,ARG0];

	warn "STDIN EVENT\n";
	#We've successfully flushed our output to the eval child
	#so shutdown the wheel's stdin

	my $wheel = $self->{ eval_wheels }->{ $id }->{ wheel};
	
	$wheel->shutdown_stdin;
}

sub eval_close {
	my( $self, $id ) = @_[OBJECT,ARG0];

	warn "CLOSE EVENT\n";
	# Sorry.
	# I should find a better way someday.
	warn "Looking for id: $id\n";

	my $wheel_struct = delete $self->{ eval_wheels }->{ $id };

	return unless $wheel_struct;

	# Get our parent's ID
	my $parent_id =  $wheel_struct->{ parent_id };

	warn "Found parent: $parent_id\n";
	my $parent_wheel = $self->{ socket_wheels }->{ $parent_id };
	
	# Send the results back to our client
	my $outputs = delete $self->{ wheel_outputs }->{ $id };

	warn "Close, my outputs: ", Dumper( $outputs );
	
	# Not sure how we end up without a $parent_wheel, but we shouldn't die
	if( $parent_wheel ) {
		if( $outputs and @$outputs ) { 
			$parent_wheel->put( [ join '', @$outputs ] );
		}
		else {
			$parent_wheel->put( [ ] );
		}
	}

}

sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];

	warn "Eval Server starting\n";

	$self->{socket_factory} = POE::Wheel::SocketFactory->new(
			BindAddress  => "127.0.0.1",
			BindPort     => '14400',
			SuccessEvent => 'socket_new',
			FailureEvent => 'socket_fail',
			Reuse        => 'on',
	);

	warn "Ready for connections...\n";

	$kernel->sig( 'CHLD' => 'dead_child' );
}

sub socket_new {
	my( $self, $handle ) = @_[OBJECT,ARG0];

	warn "Got a socket\n";
	my $wheel = POE::Wheel::ReadWrite->new( 
		Handle => $handle,
		Driver => POE::Driver::SysRW->new(),

		Filter => POE::Filter::Reference->new(),

		InputEvent   => 'socket_read',
		FlushedEvent => 'socket_write',
		ErrorEvent   => 'socket_error',
	);

	warn "Storing socket as : ", $wheel->ID, "\n";
	$self->{socket_wheels}->{ $wheel->ID } = $wheel;
}

sub socket_fail {
	warn "SOCKET FAIL: $_[ARG0],$_[ARG1]\n";
}

sub socket_read {
	my( $object, $kernel, $input, $wheel_id ) = @_[OBJECT,KERNEL,ARG0,ARG1];

	use Data::Dumper;
	warn "Got Input: ", Dumper $input;

	$kernel->yield( spawn_eval => $input, $wheel_id );
}

sub socket_write {
	my( $self, $id ) = @_[OBJECT,ARG0];

	warn "SOCKET_WRITE!\n";

	# We've received our single chunk of output for this
	# response so remove the wheel.
	my $wheel = delete $self->{socket_wheels}->{ $id };
	$wheel->shutdown_input();
	$wheel->shutdown_output();
}

sub socket_error {
	my( $self, $id ) = @_[OBJECT,ARG0];

	warn "Socket failed!\n";
	delete $self->{socket_wheels}->{ $id };
}

sub _stop {
}

sub dead_child {
	#Do nothing
	#Side effect is the child is already reaped
}

1;
