package Math::Farnsworth::Value::Undef;

use strict;
use warnings;

use Math::Farnsworth::Dimension;
use Math::Farnsworth::Value;
use Carp;

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
  my $outmagic = shift; #i'm still not sure on this one

  my $self = {};

  bless $self, $class;

  $self->{outmagic} = $outmagic;
 
  return $self;
}

#######
#The rest of this code can be GREATLY cleaned up by assuming that $one is of type, Math::Farnsworth::Value::Pari, this means that i can slowly redo a lot of this code

sub add
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to addition" unless ref($two);

  #if we're not being added to a Math::Farnsworth::Value::Pari, the higher class object needs to handle it.
  confess "Scalar value given to addition to boolean" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->add($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Boolean"))
  {
    confess "Given non boolean to boolean operation";
  }


  #NOTE TO SELF this needs to be more helpful, i'll probably do this by creating an "error" class that'll be captured in ->evalbranch's recursion and use that to add information from the parse tree about WHERE the error occured
  die "Adding booleans is not a good idea\n"; 
}

sub subtract
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to subtraction" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  die "Scalar value given to subtraction to Booleans" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->subtract($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Boolean"))
  {
    confess "Given non boolean to boolean operation";
  }

  die "Subtracting Booleans? what did you think this would do, create a black hole?";
}

sub modulus
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to modulus" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to modulus to boolean" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->mod($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Boolean"))
  {
    confess "Given non boolean to boolean operation";
  }

  die "Modulusing booleans? what did you think this would do, create a black hole?";
}

sub mult
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to multiplication" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to multiplcation to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->mult($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Boolean"))
  {
    confess "Given non boolean to boolean operation";
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
  if (!$two->istype("Boolean"))
  {
    confess "Given non boolean to boolean operation";
  }

  die "Dividing arrays? what did you think this would do, create a black hole?";
}

sub bool
{
	my $self = shift;

	#seems good enough of an idea to me
	#i have a bug HERE
	#print "BOOLCONV\n";
	#print Dumper($self);
	#print "ENDBOOLCONV\n";
	return 0;
}

sub pow
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to exponentiation" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Exponentiating arrays? what did you think this would do, create a black hole?" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->pow($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Boolean"))
  {
    confess "Given non boolean to boolean operation";
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
  confess "Scalar value given to division to array" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->compare($one, !$rev) unless ($two->ismediumtype());

  return 0;
}

