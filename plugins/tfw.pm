use strict;
use HTML::TreeBuilder;
use LWP::Simple qw/get/;

sub {
	my( $said ) = @_;

	my $location = $said->{body};

	my $resp = get( "http://thefuckingweather.com/?zipcode=$location" );

	my $tree = HTML::TreeBuilder->new_from_content( $resp );

	my $body = $tree->look_down( _tag => 'body' );

	my @elements = $body->content_list;

	my $location = $elements[0];
	my $weather = ($elements[1]->content_list)[0];
	my $remark = $tree->look_down( id => 'remark' );

	my $weathertext = $weather->as_text;
	$weathertext =~ s/\n/ /g; #filter them so when it goes ITS FUCKING NICE\nAND THUNDERING it'll display properly
		$weathertext =~ s/\?\!/?! /g;
	my $remarktext = $remark->as_text;
	$remarktext =~ s/\n/ /g;

	print $location->as_text;
	print " ";
	print $weathertext;
	print " ";
	print '(', $remarktext, ')';
}
