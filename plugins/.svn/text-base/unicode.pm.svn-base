# ------------------------
# Originally by Mauke at: http://mauke.ath.cx/stuff/perl/unip
# ------------------------

use Unicode::UCD 'charinfo';
use Encode qw/decode encode_utf8/;
use utf8;
use strict;

sub speng {
	my $x = shift;

	$x =~ /^0[0-7]+\z/ and return oct $x;

	$x =~ /^(?:[Uu]\+|0[Xx])([[:xdigit:]]+)\z/ || (
			length($x) > 1 && $x =~ /^([[:xdigit:]]*[A-Fa-f][[:xdigit:]]*)\z/
			) and return hex $1;

	$x =~ /^[0-9]+\z/ and return $x;

	return map ord, split //, $x
}

sub unip {
	my @pieces = @_;
	my (@out, @err);
	for (@pieces) {
		my $chr = chr;
		my $utf8 = join ' ', unpack '(H2)*', encode_utf8 $chr;
		my $x;
		unless ($x = charinfo $_) {
			push @err, sprintf "U+%X (%s): no match found", $_, $utf8;
			next;
		}
		push @out, "U+$x->{code} ($utf8): $x->{name} [$chr]";
	}

	\@err, \@out
}

# ------------------------

sub {
	my( $said, $pm ) = @_;

	utf8::decode( $said->{body} );

	my ($err, $out) = unip map speng($_), split " ", $said->{body};

	utf8::upgrade( $_ ) for @$err, @$out;

	print "Error: @$err\n" if @$err;
	print "@$out\n";
}

__DATA__
unicode U+2301; returns the unicode character and associated information given either a unicode character or one of the various ways you can specify a code point.
