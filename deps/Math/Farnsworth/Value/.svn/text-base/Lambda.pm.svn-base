package Math::Farnsworth::Value::Lambda;

use strict;
use warnings;

use Math::Farnsworth::Dimension;
use Math::Farnsworth::Value;
use Carp;

use Data::Dumper;

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
  my $scope = shift;
  my $args = shift;
  my $code = shift;
  my $branches = shift;
  my $outmagic = shift; #i'm still not sure on this one

  my $self = {};

  bless $self, $class;

  $self->{outmagic} = $outmagic;

  $self->{scope} = $scope;
  $self->{code} = $code;
  $self->{args} = $args;
  $self->{branches} = $branches;
  
  return $self;
}

sub getcode
{
	return $_[0]->{code};
}

sub getargs
{
	return $_[0]->{args};
}

sub getscope
{
	return $_[0]->{scope};
}

sub getbranches
{
	return $_[0]->{branches};
}

#######
#The rest of this code can be GREATLY cleaned up by assuming that $one is of type, Math::Farnsworth::Value::Pari, this means that i can slowly redo a lot of this code

sub add
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to addition" unless ref($two);

  #if we're not being added to a Math::Farnsworth::Value::Pari, the higher class object needs to handle it.
  confess "Scalar value given to addition to Lambda" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->add($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Lambda"))
  {
    confess "Given non boolean to boolean operation";
  }


  #NOTE TO SELF this needs to be more helpful, i'll probably do this by creating an "error" class that'll be captured in ->evalbranch's recursion and use that to add information from the parse tree about WHERE the error occured
  die "Adding lambda is not a good idea\n"; 
}

sub subtract
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to subtraction" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  die "Scalar value given to subtraction to Lambda" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->subtract($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Lambda"))
  {
    confess "Given non boolean to lambda operation";
  }

  die "Subtracting lambdas? what did you think this would do, create a black hole?";
}

sub modulus
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to modulus" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Scalar value given to modulus to lambda" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->mod($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Lambda"))
  {
    confess "Given non lambda to lambda operation";
  }

  die "Modulusing lambda? what did you think this would do, create a black hole?";
}

sub mult
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to multiplication" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  #confess "Scalar value given to multiplcation to lambda. ED: This will make white holes later" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->mult($one, !$rev) unless ($two->ismediumtype() || $two->istype("Pari") || $two->istype("Lambda"));
  
#  if (!$two->istype("Lambda"))
#  {
#    confess "Given non lambda to lambda operation";
#  }

  my $args = $two->istype("Array") ? $two :  new Math::Farnsworth::Value::Array([$two]); 

  #this code is debug code, but i'm afraid to take it out, when i put it here it started working properly
  #print "LAMBDAMULT\n";
  #eval{print Dumper($one->{scope}->{vars}->getvar('x'), $one->{scope}->{vars}->getvar('y'))}; #this bug was fixed

  return $one->{scope}->{funcs}->calllambda($one, $args); #needs to be updated

#  die "Multiplying lambdas? what did you think this would do, create a black hole? ED: this will make black holes later";
}

sub div
{
  my ($one, $two, $rev) = @_;

  print "INSIDE LAMBDA DIVISION\n";

  confess "Non reference given to division" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  
  return $two->div($one, !$rev) unless ($two->ismediumtype()|| $two->istype("Pari") || $two->istype("Lambda"));

  if ($two->isa("Math::Farnsworth::Value::Pari"))
  {
	  #ok i've got a simple thing here i think!
	  #its not simple, will not be simple and will not end up working right, this is a hack to make 10 kg per cubic meter, and the like to work, until i add objects
	  my $onevalue = Math::Farnsworth::Value::Pari->new(1); #don't use 1.0 it'll coerce things into floats unneccesarily
	  my $newv = $onevalue * $one; #this'll remultiply things!
	  my $ret = $two / $newv; #this COULD be dangerous since i can see how to make an inf loop in a division this way
	  return $ret;
  }

  if (!$two->istype("Lambda"))
  {
    confess "Given non boolean to lambda operation";
  }

  die "Dividing lambdas? what did you think this would do, create a black hole?";
}

sub bool
{
	#my $self = shift;

	#seems good enough of an idea to me
	#i have a bug HERE
	#print "BOOLCONV\n";
	#print Dumper($self);
	#print "ENDBOOLCONV\n";
	return 1; #for now lambdas are ALWAYS true!
}

sub pow
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to exponentiation" unless ref($two);

  #if there's a higher type, use it, subtraction otherwise doesn't make sense on arrays
  confess "Exponentiating arrays? what did you think this would do, create a black hole?" if ($two->isa("Math::Farnsworth::Value::Pari"));
  return $two->pow($one, !$rev) unless ($two->ismediumtype());
  if (!$two->istype("Lambda"))
  {
    confess "Given non boolean to lambdas operation";
  }

  die "Exponentiating lambdas? what did you think this would do, create a black hole?";
}

sub compare
{
  my ($one, $two, $rev) = @_;

  confess "Non reference given to compare" unless ref($two);

  #if we're not being added to a Math::Farnsworth::Value::Pari, the higher class object needs to handle it.
  confess "Scalar value given to division to lambdas" if ($two->istype("Pari"));
  return $two->compare($one, !$rev) unless ($two->istype("Lambda"));

  return 0; #i don't have any metric for comparing lambdas, so... they'll always be equal
}

