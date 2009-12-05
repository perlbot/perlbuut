#new value class!
package Math::Farnsworth::Value;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use base qw/Exporter/;

use Math::Farnsworth::Value::Boolean;
use Math::Farnsworth::Value::Array;
use Math::Farnsworth::Value::String;
use Math::Farnsworth::Value::Date;
use Math::Farnsworth::Value::Pari;
use Math::Farnsworth::Value::Lambda;
use Math::Farnsworth::Value::Undef;

our @EXPORT = qw(TYPE_BOOLEAN TYPE_STRING TYPE_DATE TYPE_PLAIN TYPE_TIME TYPE_LAMBDA TYPE_UNDEF TYPE_ARRAY);

####
#THESE FUNCTIONS WILL BE MOVED TO Math::Farnsworth::Value, or somewhere more appropriate

sub setref
{
	my $self = shift;
	my $ref = shift;
	$self->{_ref} = $ref;
}

sub getref
{
	my $self = shift;
	return $self->{_ref};
}

sub istype
{
	my $self = shift;
	my $allow = shift; #type to allow!

	return ref($self) =~ /\Q$allow/i;
}

sub ismediumtype
{
	my $self = shift;
	my $allow = shift; #type to allow!
	$allow ||= "";
	
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
# promoting Lambda to a High type, so that it can capture the multiplication with other types
#	elsif ($self->isa("Math::Farnsworth::Value::Lambda") && $allow ne "Lambda")
#	{
#		return 1;
#	}
	elsif ($self->isa("Math::Farnsworth::Value::Undef") && $allow ne "Undef")
	{
		return 1;
	}
	
	return 0;
}

#these values will also probably be put into a "memoized" setup so that they don't get recreated all the fucking time

{
	my $boolean;
	my $string;
	my $date;
	my $plain;
	my $time;
	my $lambda;
	my $undef;
	my $array;

	sub TYPE_BOOLEAN{return $boolean if $boolean; $boolean=new Math::Farnsworth::Value::Boolean(0)}
	sub TYPE_STRING	{return $string if $string; $string=new Math::Farnsworth::Value::String("")}
	sub TYPE_DATE	{return $date if $date; $date=new Math::Farnsworth::Value::Date("today")}
	#this tells it that it is the same as a constraint of "1", e.g. no units
	sub TYPE_PLAIN 	{return $plain if $plain; $plain=new Math::Farnsworth::Value::Pari(0)}
	#this tells it that it is the same as a constraint of "1 s", e.g. seconds
	sub TYPE_TIME	{return $time if $time; $time=new Math::Farnsworth::Value::Pari(0, {time=>1})}
	sub TYPE_LAMBDA	{return $lambda if $lambda; $lambda=new Math::Farnsworth::Value::Lambda()}
	sub TYPE_UNDEF  {return $undef if $undef; $undef=new Math::Farnsworth::Value::Undef()}
	sub TYPE_ARRAY	{return $array if $array; $array=new Math::Farnsworth::Value::Array([])}
}

sub conforms
{
	my $self = shift;
	my $comparator = shift;

	if (ref($self) ne ref($comparator))
	{
		return 0;
	}
	else
	{
		if (ref($self) eq "Math::Farnsworth::Value::Pari")
		{
			my $ret = $self->getdimen()->compare($comparator->getdimen());
			return $ret;
		}
		else
		{
			return 1; #for now?
		}
	}
}

sub clone
{
	my $self = shift;
	my $class = ref($self);

	my $newself = {};
	$newself->{$_} = $self->{$_} for (keys %$self);

	bless $newself, $class;
	$newself->setref(undef);

	$newself;
}

1;
