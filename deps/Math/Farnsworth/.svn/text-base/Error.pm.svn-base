#!/usr/bin/perl

package Math::Farnsworth::Error;

use strict;
use warnings;

use Data::Dumper;
use Carp;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(error);

use overload '""' => \&tostring,
			 'eq' => \&eq;

sub error
{
	my $err = shift;
	my $eobj = {};
    $eobj->{msg} = $err;
	bless $eobj;

	die $eobj;
}

sub tostring
{
	my $self = shift;
	return $self->{msg};
}

sub eq
{
	my ($one, $two, $rev) = @_;

	my $str = $one->tostring();
	return $str eq $two;
}
