package Math::Farnsworth::Value::Array;

use strict;
use warnings;

use Math::Farnsworth::Dimension;
#use Math::Farnsworth::Value;
use Carp;
use List::MoreUtils 'each_array'; 

use utf8;

our $VERSION = 0.6;

use overload 
    '+' => \&add,
    '-' => \&subtract,
    '*' => \&mult,
    '/' => \&div,
	'%' => \&mod,
	'**' => \&pow,
	'<=>' => \&compare,
	'bool' => \&bool;

use base qw(Math::Farnsworth::Value);

#this is the REQUIRED fields for Math::Farnsworth::Value subclasses
#
#dimen => a Math::Farnsworth::Dimension object
#
#this is so i can make a -> conforms in Math::Farnsworth::Value, to replace the existing code, i'm also planning on adding some definitions such as, TYPE_PARI, TYPE_STRING, TYPE_LAMBDA, TYPE_DATE, etc. to make certain things easier

sub new
{
  my $class = shift;
  my $value = shift;
  my $outmagic = shift; #i'm still not sure on this one

  confess "Non array reference given as \$value to constructor" unless ref($value) eq "ARRAY" && defined($value);

  my $self = {};

  bless $self, $class;

  $self->{outmagic} = $outmagic;

  $self->{array} = [@{$value}] || [];
  
  return $self;
}

sub sanitizeself
{
	my $self=shift;
	#this is to deal with a single bug i've got, it slows things down a lot :(
	
	for (@{$self->{array}})
	{
		$_->setref(undef);
	}
}

sub getarray
{
	my $self = shift;
	return @{$self->{array}};
}

sub getarrayref
{
  return $_[0]->{array};
}

sub add
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to addition" unless ref($two);

  #if we're not being added to a Math::Farnsworth::Value::Pari, the higher class object needs to handle it.
  confess "Scalar value given to addition to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->add($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Array"))
  {
    confess "Given non array to array addition";
  }

  #ONLY THIS MODULE SHOULD EVER TOUCH ->{pari} ANYMORE! this might change into, NEVER
  my $order;
  $order = [$one->getarray(), $two->getarray()] unless $rev;
  $order = [$two->getarray(), $one->getarray()] if $rev;
  my $arr = new Math::Farnsworth::Value::Array($order); #concatenate the arrays
  #$arr->sanitizeself();
  return $arr;
}

sub subtract
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to subtraction" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to subtraction to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->subtract($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Array"))
  {
    confess "Given non array to array subtraction";
  }

  die "Subtracting arrays? what did you think this would do, create a black hole?";
}

sub modulus
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to modulus" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to modulus to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->mod($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Array"))
  {
    confess "Given non array to array modulus";
  }

  die "Modulusing arrays? what did you think this would do, create a black hole?";
}

sub mult
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to multiplication" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to multiplcation to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->mult($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Array"))
  {
    confess "Given non array to array multiplication";
  }

  die "Multiplying arrays? what did you think this would do, create a black hole?";
}

sub div
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to division" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to division to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->div($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Array"))
  {
    confess "Given non array to array division";
  }

  die "Dividing arrays? what did you think this would do, create a black hole?";
}

sub bool
{
	my $self = shift;

    #boolean for array is the same as it is in perl, empty or not
	return @{$self->getarrayref()}?1:0;
}

sub pow
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to exponentiation" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Exponentiating arrays? what did you think this would do, create a black hole?" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->pow($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Array"))
  {
    confess "Given non array to array exponentiation";
  }

  die "Exponentiating arrays? what did you think this would do, create a black hole?";
}

sub __compare
{
	my ($a1, $a2) = @_;
	my $same = 0;
	my $ea = each_array(@$a1, @$a2);
	
	while(my ($first, $second) = $ea->()) 
	{ 
		$same = $first > $second ? 1 : -1 and last if $first != $second 
	} # shortcircuits

	return $same;
}

sub compare
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to compare" unless ref($two);

  #if we're not being added to a Math::Farnsworth::Value::Pari, the higher class object needs to handle it.
  return $two->compare($one, !$rev) unless ($two->ismediumtype());
  die "Can't compare two things that aren't arrays!" unless $two->isa("Math::Farnsworth::Value::Array");

  my $rv = $rev ? -1 : 1;
  my $tv = $two->getarray();
  my $ov = $one->getarray();

  #i also need to check the units, but that will come later
  #NOTE TO SELF this needs to be more helpful, i'll probably do something by adding stuff in ->new to be able to fetch more about the processing 
  die "Unable to process different units in compare\n" unless $one->conforms($two); #always call this on one, since $two COULD be some other object 

  #moving this down so that i don't do any math i don't have to
  my $new = __compare($tv, $ov);
  
  return $new * $rv;
}

