package Math::Farnsworth::FunctionDispatch;

use strict;
use warnings;

use Data::Dumper;

use Math::Farnsworth::Variables;
use Math::Farnsworth::Value::Array;
use Math::Farnsworth::Error;

use Carp;

sub new
{
	my $self = {};
	bless $self, (shift);
}

sub addfunc
{
	my $self = shift;
	my $name = shift;
	my $args = shift;
	my $value = shift;
	my $scope = shift;

	#i should really have some error checking here
	$self->{funcs}{$name} = {name=>$name, args=>$args, value=>$value, parentscope=>$scope};
}

sub getfunc
{
	my $self = shift;
	my $name = shift; #which one to get, we return the hashref
	return $self->{funcs}{$name};
}

sub isfunc
{
	my $self = shift;
	my $name = shift;

	return exists($self->{funcs}{$name});
}

sub setupargs
{
	my $self = shift;
	my $eval = shift;
	my $args = shift;
	my $argtypes = shift;
	my $name = shift; #name to display
	#my $branch = shift;

	my $vars = $eval->{vars}; #get the scope we need

ARG:for my $argc (0..$#$argtypes)
	{
		my $n = $argtypes->[$argc][0]; #the rest are defaults and constraints
		my $v = $args->getarrayref()->[$argc];

		my $const = $argtypes->[$argc][2];

		if (ref($const) eq "VarArg")
		{
		   warn "Working around bug in lambdas!";
		   $const = "VarArg";
		}

		if (!defined($v))# || ($v->{dimen}{dimen}{"undef"})) #uncomment for undef== default value
		{
			#i need a default value!
			if (!defined($argtypes->[$argc][1]) && defined($argtypes->[$argc][0])  && (defined($const) && ref($const) !~ /Math::Farnsworth::Value/ && $const ne "VarArg"))
			{
				die "Required argument $argc to function $name\[\] missing\n";
			}

			$v = $argtypes->[$argc][1];
		}

		if (defined($const) && ref($const) =~ /Math::Farnsworth::Value/)
		{
			#we have a constraint
			if (!$v->conforms($const))
			{
				die "Constraint not met on argument $argc to $name\[\]\n";
			}
		}
		elsif (defined($const) && $const eq "VarArg")
		{
			#we've got a variable argument, it needs to slurp all the rest of the arguments into an array!
			my $last = $#{$args->getarrayref()};
			my @vargs = @{$args->getarrayref()}[$argc..$last];
			my $v = new Math::Farnsworth::Value::Array(\@vargs);
			$vars->declare($n, $v); #set the variable
			last ARG; #don't parse ANY more arguments
		}

		if (defined $n)  #happens when no arguments! so we check if the name is defined
		{
			#print "SETVAR $n: ";
			#print Dumper($argtypes->[$argc]);
			#print Dumper($vars->{vars});
			if (!$argtypes->[$argc][3]) #make sure that it shouldn't be byref
			{ 
				$vars->declare($n, $v);
			}
			else
			{
				#it should be by ref
				if ($v->getref())
				{
				  $vars->setref($n, $v->getref());
			    }
				else
				{
					error "Can't get reference from expression for argument $argc";
				}
			}

			#print Dumper($vars->{vars});
		}
	}
}

#should i really have this here? or should i have it in evaluate.pm?
sub callfunc
{
	my $self = shift;
	my $eval = shift;
	my $name = shift;
	my $args = shift;
	my $branches = shift;

	my $argtypes = $self->{funcs}{$name}{args};

	my $fval = $self->{funcs}{$name}{value};

	#print "-------------ATTEMPTING TO CALL FUNCTION!-------------\n";
	#print "FUNCTION NAME : $name\n";
	#print "Dumper of func: ".Dumper($fval);
	#print "--------------------THAT IS ALL\n";

	die "Function $name is not defined\n" unless defined($fval);
	die "Number of arguments not correct to $name\[\]\n" unless $self->checkparams($args, $argtypes); #this should check....

#	print Dumper($args);

	my $neval;

	if (defined $self->{funcs}{$name}{parentscope})
	{
		$neval = $self->{funcs}{$name}{parentscope};
		
		my $nvars = new Math::Farnsworth::Variables($neval->{vars});

		my %nopts = (vars => $nvars, funcs => $self, units => $neval->{units}, parser => $neval->{parser});
		$neval = $neval->new(%nopts);
	}
	else
	{
		#this should get scrapped once i fix the other modules!
		carp "SETTING UP PARENT SCOPE OUT OF NO WHERE!";
		my $nvars = new Math::Farnsworth::Variables($eval->{vars});

		my %nopts = (vars => $nvars, funcs => $self, units => $eval->{units}, parser => $eval->{parser});
		$neval = $eval->new(%nopts);
#		$self->{funcs}{$name}{parentscope} = $neval; #store it for later!
	}

	#print "NEWSCOPE! ".$neval->{vars}."\n";

	#eval #just for fucks sake!
	#{
	#	my $facts = $neval->{vars}->getvar("facts");
	#	print "FACTS!\n";
	#	print Dumper($facts, "$facts");
	#};

	#carp "$@" if $@;

	$self->setupargs($neval, $args, $argtypes, $name, $branches); #setup the arguments

	if (ref($fval) ne "CODE")
	{
		return $self->callbranch($neval, $fval, $name);
	}
	else
	{
		#we have a code ref, so we need to call it
		return $fval->($args, $neval, $branches, $eval);
	}
}

sub calllambda
{
	my $self = shift;
	my $lambda = shift;
	my $args = shift;
#	my $refscope = shift;
#	my $branch = shift; #new for lambdas!

	my $argtypes = $lambda->getargs();
	my $fval = $lambda->getcode();
    my $eval = $lambda->getscope();

	#print "LAMBDA---------------\n";
	#print Dumper($argtypes, $args, $fval);

	my $nvars = new Math::Farnsworth::Variables($eval->{vars});

	my %nopts = (vars => $nvars, funcs => $self, units => $eval->{units}, parser => $eval->{parser});
	my $neval = $eval->new(%nopts);

	die "Number of arguments not correct to lambda\n" unless $self->checkparams($args, $argtypes); #this shoul

	$self->setupargs($neval, $args, $argtypes, "lambda");
	return $self->callbranch($neval, $fval);
}

sub callbranch
{
	my $self = shift;
	my $eval = shift;
	my $branches = shift;
	my $name = shift;


#	print "CALLBRANCHES :: ";
#	print $name if defined $name;
#	print " :: $eval\n";

	return $eval->evalbranch($branches);
}

#this was supposed to be the checks for types and such, but now its something else entirely, mostly
sub checkparams 
{
	my $self = shift;
	my $args = shift;
	my $argtypes = shift;

	my $vararg = 0;

	my $neededargs = 0;
	my $badargs = 0;

	for my $argt (@$argtypes)
	{
		$neededargs++ unless (defined($argt->[1]) || !defined($argt->[0]));
		$badargs++ if (!defined($argt->[0]));
	}

	#might want to change the !~ to something else?
	#warn "Strange bug here to investigate, lambdas produce blessed array refs for vararg... wtf";
	$vararg = 1 if (grep {defined($_->[2]) && ref($_->[2]) !~ /Math::Farnsworth::Value/ && (($_->[2] eq "VarArg") || (ref($_->[2]) eq "VarArg"))} @{$argtypes}); #find out if there is a vararg arg

	#print "NEEDED: $neededargs :: $vararg\n";
	#print Data::Dumper->Dump([$argtypes, $args->getarrayref()], [qw(argtypes args)]);

    return 1 if ($vararg || ($args->getarray() <= (@{$argtypes}-$badargs) && $args->getarray() >= $neededargs));

	#return 0 unless (ref($args) eq "Math::Farnsworth::Value") && ($args->{dimen}->compare({dimen=>{array=>1}}));

	return 0;
}

sub getref
{
	my $self = shift;
	my $argc = shift;
	my $branch = shift;
	my $name = shift;

	#print "\n\nGETREF\n";
	#print Dumper($branch);

	if (ref $branch->[1] ne "Array")
	{
		#this should add support for some other stuff
		error "Cannot get a reference if function/lambda is called without []";
	}

	my $argexpr = $branch->[1][$argc];
	
	#print Dumper($argbranches->[$argc]);
	
	if (ref $argexpr ne "Fetch")
	{
		error "Argument $argc to $name\[\] is not referencable";
	}

	my $ref = $self->{funcs}{$name}->{scope}{vars}->getref($argexpr->[0]);

	print Dumper($argexpr, $ref);

	return $ref;
}

1;
