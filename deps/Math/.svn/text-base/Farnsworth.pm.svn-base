#!/usr/bin/perl

package Math::Farnsworth;

our $VERSION = "0.6.0";

use strict;
use warnings;

use Math::Farnsworth::Evaluate;
use Math::Farnsworth::Value;
use Math::Farnsworth::Dimension;
use Math::Farnsworth::Units;
use Math::Farnsworth::FunctionDispatch;
use Math::Farnsworth::Variables;
use Math::Farnsworth::Output;
use Math::Pari;

use Carp qw(croak);

use Data::Dumper;

sub new
{
	shift; #get the class off

	my $self = {};
	my @modules = @_; #i get passed a list of modules to use for standard stuff;

	Math::Pari::setprecision(100);
	Math::Pari::allocatemem(40_000_000);

	if (@modules < 1)
	{
		#@modules = ("Units::Standard", "Functions::Standard", "Functions::StdMath", "Functions::GoogleTranslate", "Units::Currency"); #standard modules to include
	}

	#print Dumper(\@modules);

	$self->{eval} = Math::Farnsworth::Evaluate->new();

	for my $a (@modules)
	{
		eval 'use Math::Farnsworth::'.$a.'; Math::Farnsworth::'.$a.'::init($self->{eval});';
		die $@ if $@;
		#print "-------FAILED? $a\n";
		#print $@;
		#print "\n";
	}

	bless $self;
	return $self;
}

sub runString
{
	my $self = shift;
	my @torun = @_; # we can run an array
	my @results;

	push @results, new Math::Farnsworth::Output($self->{eval}{units},$self->{eval}->eval($_), $self->{eval}) for (@torun);

	return wantarray ? @results : $results[-1]; #return all of them in array context, only the last in scalar context
}

sub runFile
{
	my $self = shift;
	my $filename = shift;

	#my @results; #i should really probably only store them all IF they are needed

	open(my $fh, "<", $filename) or die "couldn't open: $!";
	my $lines;
	my $first = 1;
	while(<$fh>)
	{
		$first=0, next if ($first && $_ =~ /^#!/); #skip a shebang line, not part of the language but makes it possible to have executable .frns files!
		$lines .= $_; 
	}
    close($fh);

	#as much as i would like this to work WITHOUT this i need to filter blank lines out #not as sure i need to do this anymore! need tests to check
	$lines =~ s/\s*\n\s*\n\s*/\n/;
		
	return new Math::Farnsworth::Output($self->{eval}{units},$self->{eval}->eval($lines), $self->{eval});

#	while(<$fh>)
#	{
#		chomp;
		#s|//.*$||;
		#s|\s*$||;
#	}

#	close($fh);

		#return wantarray ? @results : $results[-1]; #return all of them in array context, only the last in scalar context
}

#this will wrap around a lot of the funky code for creating a nice looking output
#sub prettyOut
#{
#	my $self = shift;
#	my $input = shift;

#	return $input->toperl($self->{eval}{units});
#}

1;
__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Math::Farnsworth - A Turing Complete Language for Mathematics

=head1 SYNOPSIS

  use Math::Farnsworth;
  
  my $hubert = Math::Farnsworth->new();

  my $result = $hubert->runString("10 km -> miles");

  my $result = $hubert->runFile("file.frns");

  print $result;

=head1 DESCRIPTION

THIS IS A BETA RELEASE! There are typos in the error messages and in the POD.  There are also probably plenty of bugs.  It is being released early because there have been a number of people who have shown interest in having it released.  Not every feature is documented yet and a future release will have that cleaned up along with some of the hairier parts of the internal API.
Math::Farnsworth is a programming language originally inspired by Frink (see http://futureboy.homeip.net/frinkdocs/ ).
However due to certain difficulties during the creation of it, the syntax has changed slightly and the capabilities are also different.
Some things Math::Farnsworth can do a little better than Frink, other areas Math::Farnsworth lacks.

=head2 PREREQUISITS

Modules and Libraries you need before this will work

=over 4

=item *

The PARI library

=item *

L<Math::Pari>

=item *

L<Date::Manip>

The following are optional

For the Google Translation library

=item *

L<REST::Google::Translate>

=item *

L<HTML::Entities>

=back

=head2 METHODS

ALL of the methods here call C<die> whenever something doesn't go right.  This means that unless you want bad input to them to cause your program to fail you should wrap any calls to them with C<eval {}>.   When they call C<die> they will give you back a message explaining what went wrong, this is useful for telling a user what they have done.

=head3 runString

This method takes a string (or multiple strings) and executes them as Math::Farnsworth expressions.
For more information on making Math::Farnsworth expressions, see L<Math::Farnsworth::Docs::Syntax>.

=head3 runFile

This takes a file name and executes the entire file as a single Math::Farnsworth expression.

=head3 prettyOut

This takes a Math::Farnsworth::Value and turns it into a string for perl to be able to display.  This method WILL disappear in a future version.

=head2 EXPORT

None by default.

=head2 KNOWN BUGS

At the moment all known bugs are related to badly formatted output, this will be rectified in a future release.

=head2 MISSING FEATURES

The following features are currently missing and WILL be implemented in a future version of Math::Farnsworth

=over 4

=item *

Better control over the output

=over 8

=item *

Adjustable precision of numbers

=item *

Better defaults for certain types of output

=back

=item *

Passing arguments by reference

=item *

Syntax tree introspection inside the language itself

=item *

Better Documentation

=back

=head1 SEE ALSO

L<Math::Farnsworth::Docs::Syntax> L<Math::Farnsworth::Docs::Functions>


There is also an RT tracker for the module (this may change) setup at
L<http://farnsworth.sexypenguins.com/>, you can also reach the tracker by sending an email to E<lt>farnsworth.rt@gmail.comE<gt>

=head1 AUTHOR

Ryan Voots E<lt>simcop@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Ryan Voots

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
