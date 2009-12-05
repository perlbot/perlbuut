#!/usr/bin/perl

package Math::Farnsworth::Value;

use strict;
use warnings;

use Data::Dumper;

use Math::Pari;
use Math::Farnsworth::Dimension;
use Date::Manip;
use List::Util qw(sum);
use Storable qw(dclone);

use utf8;

our $VERSION = 0.5;

use overload 
    '+' => \&add,
    '-' => \&subtract,
    '*' => \&mult,
    '/' => \&div,
	'%' => \&mod,
	'**' => \&pow,
	'<=>' => \&compare,
	'bool' => \&bool;

sub new
{
  my $class = shift;
  my $value = shift;
  my $dimen = shift; #should only really be used internally?
  my $outmagic = shift; #i'm still not sure on this one

  my $self = {};

  bless $self, $class;

  $self->{outmagic} = $outmagic;
  $self->{valueinput} = $value;

  if (ref($dimen) eq "Math::Farnsworth::Dimension")
  {
    $self->{dimen} = $dimen;
  }
  else
  {
	  $dimen = {} if !defined($dimen);
	  $self->{dimen} = new Math::Farnsworth::Dimension($dimen);
  }

  if (exists($self->{dimen}{dimen}{string}) || exists($self->{dimen}{dimen}{date}) || exists($self->{dimen}{dimen}{lambda}))
  {
	$self->{pari} = $value;
  }
  elsif (exists($self->{dimen}{dimen}{array}))
  {
	#we've got an array or date or lambda here
	#use dclone() from Storable to make complete copies of everything!
#	print "CALLER: ".join("::", caller())."\n";
#	print Dumper($value);

    if (!defined($value))
	{
		#warn "OMG \$VALUE IS UNDEFINED!!!!";
		$value = [];
	}

	$self->{pari} = [@{$value}]; #this should never not be an array reference
  }
  elsif (!defined($value))
  {
	  $self->{pari} = undef;
  }
  else
  {
	$value =~ s/ee/e/i; #fixes double ee's
	$self->{pari} = PARI $value;
  }


  return $self;
}

sub toperl
{
  my $self = shift;

  return "".($self->{pari}); #stringifiying it seems to work, though i need cases for arrays!
}

sub add
{
  my ($one, $two, $rev) = @_;

  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;

  #i also need to check the units, but that will come later
  #NOTE TO SELF this needs to be more helpful, i'll probably do something by adding stuff in ->new to be able to fetch more about the processing 
  #print Dumper($one->{dimen}, $two->{dimen});
  die "Unable to process different units in addition\n" unless ($one->{dimen}->compare($two->{dimen}) || $one->{dimen}{dimen}{date}); #always call this on one, since $two COULD be some other object 

  #moving this down so that i don't do any math i don't have to

  my $new;
  if ($one->{dimen}{dimen}{string})
  {
	  #print Dumper($one, $two);
  	$new = new Math::Farnsworth::Value($one->{pari} . $tv, $one->{dimen});
  }
  elsif ($one->{dimen}{dimen}{array})
  {
	  die "Adding arrays is undefined behavoir!\n";
  }
  elsif ($one->{dimen}{dimen}{bool})
  {
	  die "Adding Booleans is undefined behavoir!\n";
  }
  elsif ($one->{dimen}{dimen}{lambda})
  {
	  die "Adding Lambdas is undefined behavoir.\n";
  }
  elsif (($one->{dimen}{dimen}{date}) && ($two->{dimen}{dimen}{date}))
  {
	  die "Adding of two dates is unsupported\n";
  }
  elsif (($one->{dimen}{dimen}{date}) && ($two->{dimen}->compare({dimen=>{time => 1}}))) #check if we are adding time to a date
  {
		  my $seconds = $two->toperl(); #calling WITHOUT the units SHOULD give me a string containing just the number
		  $seconds =~ s/\..*$//; #filter off fractional parts of a second as Date::Manip hates them
		  my $sign = $seconds > 0 ? "+" : "-"; #should work fine, even with loss of precision
		  my $delta = DateCalc($one->{pari}, "$sign $seconds seconds"); #order is switched, to make it work the way I think it should

		  $new = new Math::Farnsworth::Value($delta, {date=>1});
  }
  else
  {
	$new = new Math::Farnsworth::Value($one->{pari} + $tv, $one->{dimen});
  }

  return $new;
}

sub subtract
{
  my ($one, $two, $rev) = @_;

  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;

  #i also need to check the units, but that will come later
  #NOTE TO SELF this needs to be more helpful, i'll probably do something by adding stuff in ->new to be able to fetch more about the processing 
  die "Unable to process different units in subtraction\n" unless ($one->{dimen}->compare($two->{dimen}) || $one->{dimen}{dimen}{date}); #always call this on one, sinc

  #moving this down so that i don't do any math i don't have to
  my $new;
  if (!$rev)
  {
	  if (($one->{dimen}{dimen}{date}) && ($two->{dimen}{dimen}{date}))
	  {
		  my $delta = DateCalc($two->{pari}, $one->{pari}); #order is switched, to make it work the way I think it should
		  die "something went screwy with calculating deltas, $delta\n" unless $delta =~ /^[+-](\d+:){6}(\d+)$/;

		  my $seconds = new Math::Farnsworth::Value(Delta_Format($delta,1,"%st"), {time => 1});
		  $new = $seconds; #create that
	  }
	  elsif (($one->{dimen}{dimen}{date}) && ($two->{dimen}->compare({dimen => {time => 1}})))
	  {
		  my $seconds = $two->toperl(); #calling WITHOUT the units SHOULD give me a string containing just the number
		  $seconds =~ s/\..*$//; #filter off fractional parts of a second as Date::Manip hates them
		  my $sign = $seconds > 0 ? "-" : "+"; #should work fine, even with loss of precision
		  my $delta = DateCalc($one->{pari}, "$sign $seconds seconds"); #order is switched, to make it work the way I think it should

		  $new = new Math::Farnsworth::Value($delta, {date=>1});
	  }
	  elsif ($one->{dimen}{dimen}{date})
	  {
		  #we reached here with some other subtraction with a Date, do not do it
		  die "Dates can only have dates and time subtracted, nothing else\n";
	  }
  	  elsif ($one->{dimen}{dimen}{array} || $two->{dimen}{dimen}{array})
	  {
		  #we reached here with some other subtraction with a Date, do not do it
		  die "subtracting arrays is undefined behavior\n";
	  }
  	  elsif ($one->{dimen}{dimen}{string} || $two->{dimen}{dimen}{string})
	  {
		  #we reached here with some other subtraction with a Date, do not do it
		  die "Subtracting strings is undefined behavior\n";
	  }
	  elsif ($one->{dimen}{dimen}{bool} || $two->{dimen}{dimen}{bool})
	  {
		  #we reached here with some other subtraction with a Date, do not do it
		  die "Subtracting Booleans is undefined behavior\n";
	  }
  	  elsif ($one->{dimen}{dimen}{lambda} || $two->{dimen}{dimen}{lambda})
	  {
		  #we reached here with some other subtraction with a Date, do not do it
		  die "Subtracting lambdas is undefined behavior\n";
	  }
	  else
	  {
		  $new = new Math::Farnsworth::Value($one->{pari} - $tv, $one->{dimen}); #if !$rev they are in order
	  }
  }
  else
  {
	  die "some mistake happened here in subtraction\n"; #to test later on
#      $new = new Math::Farnsworth::Value($tv - $one->{pari}, $one->{dimen}); #if !$rev they are in order
  }
  return $new;
}

sub mod
{
  my ($one, $two, $rev) = @_;

  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;

  #i also need to check the units, but that will come later
  #NOTE TO SELF this needs to be more helpful, i'll probably do something by adding stuff in ->new to be able to fetch more about the processing 
  die "Unable to process different units in modulous\n" unless $one->{dimen}->compare($two->{dimen}); #always call this on one, since $two COULD be some other object 

  if ($one->{dimen}->compare({dimen => {string => 1}}) ||$one->{dimen}->compare({dimen => {array =>1}}) ||
	  $two->{dimen}->compare({dimen => {string => 1}}) ||$two->{dimen}->compare({dimen => {array =>1}}) ||
	  $two->{dimen}->compare({dimen => {bool => 1}})   ||$one->{dimen}->compare({dimen => {bool =>1}})  ||
	  $two->{dimen}->compare({dimen => {lambda => 1}})   ||$one->{dimen}->compare({dimen => {lambda =>1}})  ||
	  $two->{dimen}->compare({dimen => {date => 1}})   ||$one->{dimen}->compare({dimen => {date =>1}}))
  {
	  die "Can't divide arrays or strings or booleans or dates or lambdas, it doesn't make sense\n";
  }

  #moving this down so that i don't do any math i don't have to
  my $new;
  if (!$rev)
  {
	  $new = new Math::Farnsworth::Value($one->{pari} % $tv, $one->{dimen}); #if !$rev they are in order
  }
  else
  {
      $new = new Math::Farnsworth::Value($tv % $one->{pari}, $one->{dimen}); #if !$rev they are in order
  }
  return $new;
}

sub mult
{
  my ($one, $two, $rev) = @_;

  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;
  my $td = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{dimen} : new Math::Farnsworth::Dimension();
  
  if ($one->{dimen}->compare({dimen => {string => 1}}) ||$one->{dimen}->compare({dimen => {array =>1}}) ||
	  $td->compare({dimen => {string => 1}}) ||$td->compare({dimen => {array =>1}}) ||
	  $td->compare({dimen => {bool => 1}})   ||$one->{dimen}->compare({dimen => {bool =>1}})  ||
	  $td->compare({dimen => {lambda => 1}})   ||$one->{dimen}->compare({dimen => {lambda =>1}})  ||
	  $td->compare({dimen => {date => 1}})   ||$one->{dimen}->compare({dimen => {date =>1}}))  {
	  die "Can't multiply arrays or strings, it doesn't make sense\n";
  }

  my $nd = $one->{dimen}->merge($td); #merge the dimensions! don't cross the streams though

  #moving this down so that i don't do any math i don't have to
  my $new = new Math::Farnsworth::Value($one->{pari} * $tv, $nd);
  return $new;
}

sub div
{
  my ($one, $two, $rev) = @_;

  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;
  my $td = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{dimen} : new Math::Farnsworth::Dimension();

  if ($one->{dimen}->compare({dimen => {string => 1}}) ||$one->{dimen}->compare({dimen => {array =>1}}) ||
	  $td->compare({dimen => {string => 1}}) ||$td->compare({dimen => {array =>1}}) ||
	  $td->compare({dimen => {bool => 1}})   ||$one->{dimen}->compare({dimen => {bool =>1}})  ||
	  $td->compare({dimen => {lambda => 1}}) ||$one->{dimen}->compare({dimen => {lambda =>1}})  ||
	  $td->compare({dimen => {date => 1}})   ||$one->{dimen}->compare({dimen => {date =>1}})) 
  {
	  die "Can't divide arrays or strings, it doesn't make sense\n";
  }

  #these are a little screwy SO i'll probably comment them more later
  #probably after i find out that they're wrong
  my $qd = $rev ? $td : $one->{dimen};
  my $dd = $rev ? $one->{dimen}->invert() : (ref($td) eq "HASH" ? $td : $td->invert());

  my $nd;
  
  if (ref($qd) ne "HASH")
  {
	  $nd = $qd->merge($dd); #merge the dimensions! don't cross the streams though
  }
  else
  {
	  $nd = $dd->merge($qd); #merge them the other way, because $qd is a "HASH" and not an object
  }

  #moving this down so that i don't do any math i don't have to
  my $new;
  if (!$rev)
  {
	  $new = new Math::Farnsworth::Value($one->{pari} / $tv, $nd); #if !$rev they are in order
  }
  else
  {
      $new = new Math::Farnsworth::Value($tv / $one->{pari}, $nd); #if !$rev they are in order
  }

  return $new;
}

sub bool
{
	my $self = shift;

	#seems good enough of an idea to me
	#i have a bug HERE
	#print "BOOLCONV\n";
	#print Dumper($self);
	#print "ENDBOOLCONV\n";
	return $self->{pari}?1:0;
}

sub pow
{
  my ($one, $two, $rev) = @_;

  if ($one->{dimen}->compare({dimen => {string => 1}}) ||$one->{dimen}->compare({dimen => {array =>1}}) ||
	  $two->{dimen}->compare({dimen => {string => 1}}) ||$two->{dimen}->compare({dimen => {array =>1}}) ||
	  $two->{dimen}->compare({dimen => {bool => 1}})   ||$one->{dimen}->compare({dimen => {bool =>1}})  ||
	  $two->{dimen}->compare({dimen => {lambda => 1}})   ||$one->{dimen}->compare({dimen => {lambda =>1}})  ||
	  $two->{dimen}->compare({dimen => {date => 1}})   ||$one->{dimen}->compare({dimen => {date =>1}})) 
  {
	  die "Can't exponentiate arrays or strings or dates or bools, it doesn't make sense\n";
  }

  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;
  my $td = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{dimen} : undef;

  if (defined($td) && !$td->compare({dimen=>{}}))
  {
	  die "A number with units as the exponent doesn't make sense";
  }

  #moving this down so that i don't do any math i don't have to
  my $new;
  if (!$rev)
  {
	  $new = new Math::Farnsworth::Value($one->{pari} ** $tv, $one->{dimen}->mult($tv)); #if !$rev they are in order
  }
  else
  {
#	  print Dumper(\@_);
	  #print "POW: $tv :: $two :: $one\n";
      $new = new Math::Farnsworth::Value($tv ** $one->{pari}, $one->{dimen}->mult($tv)); #if !$rev they are in order
  }

  return $new;
}

sub compare
{
  my ($one, $two, $rev) = @_;

  my $rv = $rev ? -1 : 1;
  #check for $two being a simple value
  my $tv = ref($two) && $two->isa("Math::Farnsworth::Value") ? $two->{pari} : $two;

  #i also need to check the units, but that will come later
  #NOTE TO SELF this needs to be more helpful, i'll probably do something by adding stuff in ->new to be able to fetch more about the processing 
  die "Unable to process different units in compare\n" unless $one->{dimen}->compare($two->{dimen}); #always call this on one, since $two COULD be some other object 

  #moving this down so that i don't do any math i don't have to
  my $new;
  
  if ($one->{dimen}{dimen}{string})
  {
	  if ($one->{pari} eq $tv)
	  {
		  $new = 0;
	  }
	  elsif ($one->{pari} lt $tv)
	  {
		  $new = -1;
	  }
	  elsif ($one->{pari} gt $tv)
	  {
		$new = 1;
	  }
  }
  elsif ($one->{dimen}{dimen}{array})
  {
	  die "Comparing arrays has not been implemented\n";
  }
  elsif ($one->{dimen}{dimen}{lambdas})
  {
	  die "Comparing lambdas has not been implemented\n";
  }
  elsif ($one->{dimen}{dimen}{date})
  {
	  return Date_Cmp($one->{pari}, $two->{pari}); #does it for me!
  }
  else
  {
	  if ($one->{pari} == $tv)
	  {
		  $new = 0;
	  }
	  elsif ($one->{pari} < $tv)
	  {
		  $new = -1;
	  }
	  elsif ($one->{pari} > $tv)
	  {
		$new =1;
	  }
  }

  return $new;
}

