use List::Util qw(min);

	
	my $findcommon = sub {
		my @input = map {lc $_} @_;
		my $min = min(map {length $_} @input);
		my $common = "";
		
		for my $i (0..$min-1)
		{
			my $count = 1;
			for my $j (1..$#input)
			{
				$count++ if (substr($input[0], $i, 1) eq substr($input[$j], $i, 1))
			}
			
			$common .= substr($input[0], $i, 1) if ($count == @input) # did it match all inputs?
		}
		
		return $common;
	};

my $a=sub {
	my( $said ) = @_;
    #$said->{body} =~ s/^[^,]*://;
    
    my $ors =()= $said->{body}=~m/\bor\b/g;
    my $common = "";

    my @a;

	if ($ors >= 1)
	{
		@a = split(/(?:\bor\b|\s*,\s*)+/, $said->{body});
	    
		s/^\s*//, s/\s*(\?\s*)?$// for @a; #trim them up
		
		$common = $findcommon->(@a);
		
		if ($common =~ /\s$/) #only remove if we end on whitespace
		{
		  s/^$common// for @a; # remove the common stuff for grammar
		}
	}
	else
	{
       @a=("Outlook good",
           "Outlook not so good",
           "My reply is no",
           "Don't count on it",
           "You may rely on it",
           "Ask again later",
           "Most likely",
           "Cannot predict now",
           "Yes",
           "Yes, definitely",
           "Better not tell you now",
           "It is certain",
           "Very doubtful",
           "It is decidedly so",
           "Concentrate and ask again",
           "Signs point to yes",
           "My sources say no",
           "Without a doubt",
           "Reply hazy, try again",
           "As I see it, yes");
	}

     print $a[rand@a]
};

return $a

__DATA__
8ball, magic 8ball if you don't understand then you need to stop having a life.
