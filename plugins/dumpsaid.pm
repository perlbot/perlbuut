use Data::Dumper;

no warnings 'void';
sub {
	my( $said ) = @_;
	
	print Dumper($said);
  return "FOO";
};

__DATA__
Prints the full said object out, used for debugging
