package Math::Farnsworth::Output;

use strict;
use warnings;

use overload '""' => \&tostring;

use Data::Dumper;
use Date::Manip;
use Carp qw(cluck carp confess);

our %combos;
our %displays;

#these primarily are used for display purposes
sub addcombo
{
	my $name = shift;
	my $value = shift; #this is a valueless list of dimensions

	$combos{$name} = $value;
}

#this returns the name of the combo that matches the current dimensions of a Math::Farnsworth::Value::Pari
sub findcombo
{
	my $self = shift;
	my $value = shift;

	for my $combo (keys %combos)
	{
		my $cv = $combos{$combo}; #grab the value
		return $combo if ($value->getdimen()->compare($cv->getdimen()));
	}

	return undef; #none found
}

#this sets a display for a combo first, then for a dimension
sub setdisplay
{
	my $self = shift;
	my $name = shift; #this only works on things created by =!= or |||, i might try to extend that later but i don't think i need to, since you can just create a name with ||| when you need it
	my $branch = shift;

	#I SHOULD CHECK FOR THE NAME!!!!!
	#print Dumper($name, $branch);

	if (exists($combos{$name}))
	{
		$displays{$name} = $branch;
	}
	else
	{
		die "No such dimension/combination as $name\n";
	}
}

sub getdisplay
{
	my $self = shift;
	my $name = shift;

	if (defined($name) && exists($displays{$name}))
	{
		return $displays{$name}; #guess i'll just do the rest in there?
	}

	return undef;
}

sub new
{
  shift; #remove the class
  my $self = {};
  $self->{units} = shift;
  $self->{obj} = shift;
  $self->{eval} = shift;

  #warn Dumper($self->{obj});
  die "Attempting to make output class of non Math::Farnsworth::Value" unless ref($self->{obj}) =~ /Math::Farnsworth::Value/;
  confess "Forgot to add \$eval to params!" unless ref($self->{eval}) eq "Math::Farnsworth::Evaluate";

  bless $self;
}

sub tostring
{
  my $self = shift;
  my $value = $self->{obj};

  return $self->getoutstring($value);
}

#this takes a set of dimensions and returns what to display
sub getoutstring
{
	my $self = shift; #i'll implement this later too
#	my $dimen = shift; #i take a Math::Farnsworth::Dimension object!
    my $value = shift; #the value so we can stringify it

    my @returns;

	if (defined($value->{outmagic}))
	{
		if (ref($value->{outmagic}[1]) eq "Math::Farnsworth::Value::String")
		{
			#ok we were given a string!
			my $number = $value->{outmagic}[0];
			my $string = $value->{outmagic}[1];
			return $self->getoutstring($number) . " ".$string->getstring();
		}
		elsif (exists($value->{outmagic}[0]) && (ref($value->{outmagic}[0]) ne "Math::Farnsworth::Value::Array"))
		{
			#ok we were given a value without the string
			my $number = $value->{outmagic}[0];
			return $self->getoutstring($number);
		}
		else
		{
			print Dumper($value);
			die "Unhandled output magic, this IS A BUG!";
		}
	}
	elsif (ref($value) eq "Math::Farnsworth::Value::Boolean")
	{
		return $value ? "True" : "False"
		#these should do something!
	}
	elsif (ref($value) eq "Math::Farnsworth::Value::String")
	{
		#I NEED FUNCTIONS TO HANDLE ESCAPING AND UNESCAPING!!!!
		my $val = $value->getstring();
		$val =~ s/\\/\\\\/g; 
		$val =~ s/"/\\"/g;
		return '"'.$val.'"';
	}
	elsif (ref($value) eq "Math::Farnsworth::Value::Array")
	{
		my @array; #this will be used to build the output
		for my $v ($value->getarray())
		{
			#print Dumper($v);
			push @array, $self->getoutstring($v);
		}

		return '['.(join ' , ', @array).']';
	}
	elsif (ref($value) eq "Math::Farnsworth::Value::Date")
	{
		return $value->getdate()->strftime("# %F %H:%M:%S.%3N %Z #");#UnixDate($value->{pari}, "# %C #"); #output in ISO format for now
	}
	elsif (ref($value) eq "Math::Farnsworth::Value::Lambda")
	{
		
		return $self->deparsetree($value->getbranches());
	}
	elsif (ref($value) eq "Math::Farnsworth::Value::Undef")
	{
		return "undef";
	}
	elsif (ref($value) eq "HASH")
	{
		warn "RED ALERT!!!! WE've got a BAD CASE HERE. We've got an UNBLESSED HASH";
		warn Dumper($value);

		return "undef";
	}
	elsif (my $disp = $self->getdisplay($self->findcombo($value)))
	{
		#$disp should now contain the branches to be used on the RIGHT side of the ->
		#wtf do i put on the left? i'm going to send over the Math::Farnsworth::Value, this generates a warning but i can remove that after i decide that its correct

		print "SUPERDISPLAY:\n";
		my $branch = bless [$value, $disp], 'Trans';
		print Dumper($branch);
		my $newvalue = eval {$self->{eval}->evalbranch($branch);};
		return $self->getoutstring($newvalue);
	}
	else
	{
		my $dimen = $value->getdimen();
		#added a sort so its stable, i'll need this...
		for my $d (sort {$a cmp $b} keys %{$dimen->{dimen}})
		{
			my $exp = "";
			#print Dumper($dimen->{dimen}, $exp);
			my $dv = "".($dimen->{dimen}{$d});
			my $realdv = "".(0.0+$dimen->{dimen}{$d}); #use this for comparing below, that way i can keep rational exponents when possible

			$dv =~ s/([.]\d+?)0+$/$1/;
			$dv =~ s/E/e/; #make floating points clearer

			$exp = "^".($dv =~ /^[\d\.]+$/? $dv :"(".$dv.")") unless ($realdv eq "1");
			
			push @returns, $self->{units}->getdimen($d).$exp;
		}
		
		if (my $combo = $self->findcombo($value)) #this should be a method?
		{
			push @returns, "/* $combo */";
		}


		my $prec = Math::Pari::setprecision();
		Math::Pari::setprecision(15); #set it to 15?
		my $pv = "".(Math::Pari::pari_print($value->getpari()));
		my $parenflag = $pv =~ /^[\d\.e]+$/i;
		my $rational = $pv =~ m|/|;

		$pv =~ s/E/e/; #make floating points clearer

		if ($pv =~ m|/|) #check for rationality
		{
			my $nv = "".Math::Pari::pari_print($value->getpari() * 1.0); #attempt to force a floating value
			$nv =~ s/([.]\d+?)0+$/$1/ ;
			$pv .= "  /* apx ($nv) */";
		}

		$pv = ($parenflag? $pv :"(".$pv.")"); #check if its a simple value, or complex, if it is complex, add parens
		$pv =~ s/([.]\d+?)0+$/$1/ ;

		Math::Pari::setprecision($prec); #restore it before calcs
		return $pv." ".join " ", @returns;
	}
}

sub deparsetree
{
	my $self = shift;
	my $branch = shift;

	my $type = ref($branch);
	my $return;
	
	if ($type eq "Add")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return $a . " + " . $b;
	}
	elsif ($type eq "Sub")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return $a . " - " . $b;
	}
	elsif ($type eq "Mul")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		my $t = $branch->[2];

		return $a . ($t eq 'imp' ? '' : ' * ') . $b; #NOTE: this should listen to the 'imp' or '*' in the tree!
	}
	elsif ($type eq "Div")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		my $t = $branch->[2];

		$return = $a . " $t " . $b;
	}
	elsif ($type eq "Conforms")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a conforms $b";
	}
	elsif ($type eq "Mod")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a % $b";
	}
	elsif ($type eq "Pow")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a ^ $b";
	}
	elsif ($type eq "And")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);

		return "$a && $b";
	}
	elsif ($type eq "Or")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		
		return "$a || $b";
	}
	elsif ($type eq "Xor")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a ^^ $b";
	}
	elsif ($type eq "Not")
	{
		my $a = $self->deparsetree($branch->[0]);
		return "!$a";
	}
	elsif ($type eq "Gt")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a > $b";
	}
	elsif ($type eq "Lt")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a < $b";
	}
	elsif ($type eq "Ge")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a >= $b";
	}
	elsif ($type eq "Le")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a <= $b";
	}
	elsif ($type eq "Compare")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a <=> $b";
	}
	elsif ($type eq "Eq")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a == $b";
	}
	elsif ($type eq "Ne")
	{
		my $a = $self->deparsetree($branch->[0]);
		my $b = $self->deparsetree($branch->[1]);
		return "$a != $b";
	}
	elsif ($type eq "Ternary")
	{
		my $left = $self->deparsetree($branch->[0]);
		my $one = $self->deparsetree($branch->[1]);
		my $two = $self->deparsetree($branch->[2]);

		return "$left ? $one : $two";
	}
	elsif ($type eq "If")
	{
		my $return = "";
		my $left = $self->deparsetree($branch->[0]);
        my $std = $self->deparsetree($branch->[1]);
		
		$return = "if ($left) { $std }";

		if ($branch->[2])
		{
			my $else = $self->deparsetree($branch->[2]);
			$return .= " else { $else }";
		}
		
		#$return .= ";"; #NOTE: DO I NEED THIS? probably not!

		return $return;
	}
	elsif ($type eq "Store")
	{
		my $name = $branch->[0];
		my $value = $self->deparsetree($branch->[1]);

		return "$name = $value";
	}
	elsif ($type eq "DeclareVar")
	{
		my $name = $branch->[0];

		my $return = "var $name";

		if (defined($branch->[1]))
		{
			my $val =  $self->deparsetree($branch->[1]);
			$return .= " = $val";
		}

		return $return;
	}
	elsif ($type eq "FuncDef")
	{
		#print Dumper($branch);
		my $name = $branch->[0];
		my $args = $branch->[1];
		my $value = $self->deparsetree($branch->[2]); #not really a value, but in fact the tree to run for the function

		my $return = "${name}{";

		my $vargs = "";

		for my $arg (@$args)
		{
			my $foobs="";
			my $constraint = $arg->[2];
			my $default = $arg->[1];
			my $name = $arg->[0]; #name

			$foobs = $name;
			if (defined($default))
			{
				$foobs .= " = ".$self->deparsetree($default); #should be right
			}

			if (defined($constraint))
			{
				#print Dumper($constraint);
				$foobs .= " isa ".$self->deparsetree($constraint); #should be right
				#print Dumper($constraint);
			}

			$vargs .= $foobs;
		}

		$return .= "$vargs} := { $value }";
	}
	elsif ($type eq "FuncCall")
	{
		my $name = $branch->[0];
		my $args = $self->deparsetree($branch->[1]); #this is an array, need to evaluate it

		return "$name\[$args\]";
	}
	elsif ($type eq "Lambda")
	{
		my $args = $branch->[0];
		my $code = $self->deparsetree($branch->[1]);

		my $vargs = "";

		for my $arg (@$args)
		{
			my $foobs="";
			my $reference = $arg->[3];
			my $constraint = $arg->[2];
			my $default = $arg->[1];
			my $name = $arg->[0]; #name

			$foobs = $name;
			if ($reference)
			{
				$foobs .= " byref "; #should be right
			}

			if (defined($default))
			{
				$foobs .= " = ".$self->deparsetree($default); #should be right
			}

			if (defined($constraint))
			{
				#print Dumper($constraint);
				$foobs .= " isa ".$self->deparsetree($constraint); #should be right
				#print Dumper($constraint);
			}

			$vargs .= $foobs;
		}

		return "{`$vargs` $code}";
	}
	elsif ($type eq "LambdaCall")
	{		
		my $left = $self->deparsetree($branch->[0]);
		my $right = $self->deparsetree($branch->[1]);

		return "$left => $right";
	}
	elsif (($type eq "Array") || ($type eq "SubArray"))
	{
		my $array = []; #fixes bug with empty arrays
		for my $bs (@$branch) #iterate over all the elements
		{
			my $type = ref($bs); #find out what kind of thing we are
			my $value = $self->deparsetree($bs);

			#since we have an array, but its not in a SUBarray, we dereference it before the push
			push @$array, $value;
			#push @$array, '['.$value.']' if ($type eq "SubArray");
		}
		return '[ '.(join ', ',@$array).' ]';
		
	}
	elsif ($type eq "ArgArray")
	{
		my $array = [];
		for my $bs (@$branch) #iterate over all the elements
		{
			my $value = $self->deparsetree($bs);

			push @$array, $value; #we return an array ref! i need more error checking around for this later
		}
		return join ', ', @$array;
	}
	elsif ($type eq "ArrayFetch")
	{
		my $var = $self->deparsetree($branch->[0]); #need to check if this is an array, and die if not
		my $listval = $self->deparsetree($branch->[1]);
		
		$listval = substr $listval, 1,length($listval)-2; #strip the []

		return "$var\@$listval\$";
	}
	elsif ($type eq "ArrayStore")
	{
		my $var = $self->deparsetree(bless [$branch->[0]], 'Fetch'); #need to check if this is an array, and die if not
		my $listval = $self->deparsetree($branch->[1]);
		my $rval = $self->deparsetree($branch->[2]);

		$listval = substr $listval, 1,length($listval)-2; #strip the []

		return "$var\@$listval\$ = $rval";
	}
	elsif ($type eq "While")
	{
		my $cond = $self->deparsetree($branch->[0]); #what to check each time
		my $stmts = $self->deparsetree($branch->[1]); #what to run each time

		return "while ($cond) { $stmts }"
	}
	elsif ($type eq "Stmt")
	{
		my $return = "";
		for my $bs (@$branch) #iterate over all the statements
		{   my $r = $self->deparsetree($bs);
			$return .= "$r; " if defined $r; #this has interesting semantics!
		}
		return $return;
	}
	elsif ($type eq "Paren")
	{
		return '(' . $self->deparsetree($branch->[0]) . ')';
	}
	elsif ($type eq "SetDisplay")
	{
		my $combo = $branch->[0][0]; #is a string?
		my $right = $self->deparsetree($branch->[1]);

		return "$combo :-> $right";
	}
	elsif ($type eq "UnitDef")
	{
		my $unitsize = $self->deparsetree($branch->[1]);
		my $name = $branch->[0];
		
		return "$name := $unitsize";
	}
	elsif ($type eq "DefineDimen")
	{
		my $unit = $branch->[1];
		my $dimen = $branch->[0];
		
		return "$dimen =!= $unit";
	}
	elsif ($type eq "DefineCombo")
	{
		my $combo = $branch->[1]; #should get me a string!
		my $value = $self->deparsetree($branch->[0]);
		
		return "$value ||| $combo";
	}
	elsif (($type eq "SetPrefix") || ($type eq "SetPrefixAbrv"))
	{
		my $name = $branch->[0];
		my $value = $self->deparsetree($branch->[1]);

		return "$name ::- $value";
	}
	elsif ($type eq "Trans")
	{
		my $left = $self->deparsetree($branch->[0]);
		my $right = $self->deparsetree($branch->[1]);

		return "$left -> $right";
	}
	elsif (($type eq "Num") || ($type eq "Fetch") || ($type eq "HexNum"))
	{
		return $branch->[0]; #its already a string!
	}
	elsif ($type eq "String")
	{
		return '"'.$branch->[0].'"';
	}
	elsif ($type eq "Date")
	{
		return "#".$branch->[0]."#";
	}
	elsif ($type eq "VarArg")
	{
		return "...";
	}
	elsif (!defined($branch))
	{
		return ""; #got an undefined value, just make it blank
	}
	else
	{
#		cluck "Unhandled input!";
		return '/*'.Dumper($branch).'*/';
	}
}

sub makevalue
{
	confess "MAKEVALUE WAS CALLED!\n";
}

1;
__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Math::Farnsworth::Output - Wrapper class for making output simpler

=head1 SYNOPSIS

  use Math::Farnsworth;
  
  my $hubert = Math::Farnsworth->new();

  my $result = $hubert->runString("10 km -> miles");

  my $result = $hubert->runFile("file.frns");

  print $result;

=head1 METHODS

This has only one method that a user should be aware of, C<tostring>; you can call this directly on the object, e.g. $result->tostring() 

=head1 AUTHOR

Ryan Voots E<lt>simcop@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Ryan Voots

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
