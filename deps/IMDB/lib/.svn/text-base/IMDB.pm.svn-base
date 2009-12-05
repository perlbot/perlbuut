package IMDB;
use HTML::TreeBuilder;
use URI;
use LWP::Simple qw/get/;
use URI::Escape qw/uri_escape/;
use strict;


sub normalize_title
{
	my( $self, $title ) = @_;

	$title =~ tr/'"[]//d;
	$title =~ s/ +/ /g;
	return $title;
}

sub new
{
	my( $class, $title ) = @_;
	my $self = bless {}, $class;

	my ($uri,$tree) = $self->search( $title );
	return unless defined $tree;

	$self->get_title($tree);
	$self->get_basic_info($tree);

	for( qw/plotsummary fullcredits trivia quotes/ )
	{
		warn "Fetching $uri$_\n";
		my $html = get( "$uri$_" );
		my $tree = HTML::TreeBuilder->new;
		$tree->parse($html);
		$tree->eof;

		my $method_name = "get_$_";
		$self->$method_name($tree);
	}

	return $self;
}

sub search
{
	my( $self, $title ) = @_;
	my $search_uri = "http://www.imdb.com/find?s=all&q=" . uri_escape($self->normalize_title($title));
	warn "Fetching $search_uri\n";
	my $html = get($search_uri);

	my $tree = HTML::TreeBuilder->new;
	$tree->parse($html);
	$tree->eof;

	if( not $tree->look_down(_tag => "title")->as_text =~ /IMDb.*Search/ )
	{
		my $link = $tree->look_down( _tag => 'a', href => qr#/title/tt# );
		$link->attr('href') =~ m'(/title/tt\d+)';
		return ( "http://www.imdb.com$1",$tree );
	}

	#This gets the initial header for the search results. <h2>Popular Results</h2>
	my $top_ele = $tree->look_down( _tag => 'b', sub { $_[0]->as_text eq 'Popular Titles' } );

	if( $top_ele and ($top_ele->parent->content_list)[2] )
	{
		$top_ele = ($top_ele->parent->content_list)[2]; #Should be the opening tag for the follow list of links.
	}

	else
	{
		$top_ele = $tree->look_down( _tag => 'b', sub { $_[0]->as_text eq 'Titles (Exact Matches)' } );

		if( $top_ele )
		{
			$top_ele = ($top_ele->right)[1];
		}

		else
		{
			$top_ele = $tree->look_down( _tag => 'b', sub { $_[0]->as_text eq 'Titles (Approx Matches)' } );

			if( $top_ele )
			{
				$top_ele = ($top_ele->right)[1];
			}

			else
			{
				$top_ele = $tree->look_down( _tag => 'b', sub { $_[0]->as_text eq 'Titles (Partial Matches)' } );

				if( $top_ele )
				{
					$top_ele = ($top_ele->right)[1];
				}

				else
				{
					warn "Error, could not find a useful result for term $title\n";
					return;
				}
			}
		}
	}

#  warn "Top ele -- ", $top_ele->as_HTML;

	my $first_link = $top_ele->look_down( _tag => 'a' ); #We only want the first link anyway.

	my $path = URI->new($first_link->attr('href'))->path; 
	my $uri = URI->new_abs( $path, "http://imdb.com");
	$self->{data}->{uri} = $uri;

	my $actual_html = get( $uri );
	my $new_tree = HTML::TreeBuilder->new;
	$new_tree->parse($actual_html);
	return ($uri,$new_tree);
}


sub get_title
{
	my( $self, $tree ) = @_;
	
	my $title = $tree->look_down(_tag => "title");
	$self->{data}->{title} = $title->as_text if $title;
}

sub get_basic_info
{
	my( $self, $tree ) = @_;

	my $rdate = $tree->look_down( _tag => 'h5', sub { $_[0]->as_text eq 'Release Date:' } );
	$self->{data}->{release_date} = $rdate->right if $rdate;
	my $genre_title = $tree->look_down( _tag => 'h5', sub { $_[0]->as_text eq 'Genre:' } );
	
	if( $genre_title )
	{
		my @genres = $genre_title->right;
		pop @genres; #Remove the "more.." link.

		if( @genres )
		{
			$self->{data}->{genre} .= (ref $_ ? $_->as_text : $_) for @genres;
		}
	}
}

sub get_plotsummary
{
	my( $self, $tree ) = @_;
	
	my $first_summary = $tree->look_down( _tag => 'p', class => 'plotpar' );
	if( $first_summary )
	{
		$self->{data}->{summary} = $first_summary->as_text;
	}
}

sub get_quotes
{
	my( $self, $tree ) = @_;

	my $first_link = $tree->look_down( _tag => "a", name => qr/qt\d+/ ); 
	return unless $first_link;
	my @quote_eles = ($first_link,$first_link->right);

	my $quotes;

	for( my $i = 0; $i < $#quote_eles; $i++ )
	{
		local $_ = $quote_eles[$i];

		if( ref $_ and $_->tag eq 'a' and $_->attr('name') =~ /qt\d+/ )
		{
			my @quote;

			my $start = $i;
			for( $i; $i < @quote_eles; $i++ )
			{
				local $_ = $quote_eles[$i];
				
				if( ref $_ and ( $_->tag eq 'hr' or $_->tag eq 'div' ) )
				{
					last;
				}

				if( ref $_ and $_->tag eq 'i' )
				{
					$quote[-1] .= $_->as_text;
					$i++;
					#Hrm, this should probably always be plain text..
					$quote[-1] .= ref $quote_eles[$i] ? $quote_eles[$i]->as_text : $quote_eles[$i];  
				}
				else
				{
					my $str = ref $_ ? $_->as_text : $_;
					if( $str =~ /\S/ ) { push @quote, $str }
				}
			}
			
			for( my $j = 0; $j < @quote; $j++ )
			{ 
				if( $quote[$j] =~ /:/ )
				{
					$quote[$j-1].=$quote[$j];
					$quote[$j]='';
				}
			}

			s/^\s+//,s/\s+$// for @quote;
			@quote = grep length $_, @quote;
			push @$quotes, \@quote;
		}
	}

	$self->{data}->{quotes} = $quotes;
}

sub get_trivia
{
	my( $self, $tree ) = @_;

	my @trivia;
	for my $ul ($tree->look_down( _tag => "ul", class => "trivia" ) )
	{
		for( $ul->look_down( _tag => "li" ) )
		{
			push @trivia, $_->as_text;
		}
	}

	$self->{data}->{trivia} = \@trivia;	
}

sub get_fullcredits
{
	my( $self, $tree ) = @_;
}

1;
