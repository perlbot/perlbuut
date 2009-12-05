#new value class!
package Math::Farnsworth::Value;

use strict;
use warnings;

use Carp;

####
#THESE FUNCTIONS WILL BE MOVED TO Math::Farnsworth::Value, or somewhere more appropriate

sub ismediumtype
{
	my $self = shift;
	my $allow = shift; #type to allow!
	
	if ($self->isa("Math::Farnsworth::Value::Array") && $allow ne "Array")
	{
		return 1;
	}
	elsif ($self->isa("Math::Farnsworth::Value::Boolean") && $allow ne "Boolean")
	{
		return 1;
	}
	elsif ($self->isa("Math::Farnsworth::Value::String") && $allow ne "String")
	{
		return 1;
	}
	elsif ($self->isa("Math::Farnsworth::Value::Date") && $allow ne "Date")
	{
		return 1;
	}
	elsif ($self->isa("Math::Farnsworth::Value::Lambda") && $allow ne "Lambda")
	{
		return 1;
	}
	elsif ($self->isa("Math::Farnsworth::Value::Undef") && $allow ne "Undef")
	{
		return 1;
	}
	
	return 0;
}

#these values will also probably be put into a "memoized" setup so that they don't get recreated all the fucking time
sub TYPE_BOOLEAN
{
	new Math::Farnsworth::Value::Boolean(0);
}

sub TYPE_STRING
{
	new Math::Farnsworth::Value::String("");
}

sub TYPE_DATE
{
	new Math::Farnsworth::Value::Date();
}

sub TYPE_PLAIN #this tells it that it is the same as a constraint of "1", e.g. no units
{
	new Math::Farnsworth::Value::Pari(0);
}

sub TYPE_TIME #this tells it that it is the same as a constraint of "1", e.g. no units
{
	new Math::Farnsworth::Value::Pari(0, {time=> 1});
}

sub TYPE_LAMBDA
{
	new Math::Farnsworth::Value::Lambda();
}

sub TYPE_UNDEF
{
	new Math::Farnsworth::Value::Undef();
}

sub TYPE_ARRAY
{
	new Math::Farnsworth::Value::Array();
}
