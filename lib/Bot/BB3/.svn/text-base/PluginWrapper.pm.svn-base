package Bot::BB3::PluginWrapper;

use strict;

{
	package PluginWrapper::WrapSTDOUT;
	
	sub TIEHANDLE {
		my( $class, $buffer_ref ) = @_;
		return bless { buffer => $buffer_ref }, $class;
	}

	sub PRINT {
		my( $self, @args ) = @_;
		${ $self->{buffer} } .= join $", @args;

		return 1;
	}

	sub PRINTF {
		my( $self, $format, @args ) = @_;
		${ $self->{buffer} } .= sprintf $format, @args;

		return 1;
	}

}

sub new {
	my( $class, $name, $coderef ) = @_;

	my $self = bless { coderef => $coderef, name => $name }, $class;
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;
	my( $name ) = $self->{name};

	my $output;
	local *STDOUT;
	tie *STDOUT, 'PluginWrapper::WrapSTDOUT', \$output;

	$self->{coderef}->($said,$pm);

	untie *STDOUT;

	return( 'handled', $output );
}


1;
