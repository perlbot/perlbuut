package Bot::BB3::Plugin::Package;
use POE::Component::IRC::Common qw/l_irc/;
use DBD::SQLite;
use strict;

sub new {
	my( $class ) = @_;
	my $self = bless {}, $class;
	$self->{name} = "package";
	$self->{opts} = {
		command => 1,
	};

	return $self;
}

sub dbh {
	my( $self ) = @_;

	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = $self->{dbh} = DBI->connect( "dbi:SQLite:dbname=var/perlpacks.db", "", "", { PrintError => 0, RaiseError => 1 } );

	return $dbh;
}
	
sub command {
	my( $self, $said, $pm ) = @_;
	my( $dist, $module ) = @{ $said->{recommended_args} };

	my $package = $self->dbh->selectrow_arrayref( "SELECT package FROM packages WHERE distro = ? AND module = ?", 
		undef, 
	    lc $dist,
        $module
	);

	if( $package and @$package and $package->[0] ) {

		return( 'handled', "You should find $module in the $dist package named: ".$package->[0] );
	}
	else {
		return( 'handled', "I don't know where to find $module in $dist.  Try CPAN" );
	}
}

no warnings 'void';
"Bot::BB3::Plugin::Package";

__DATA__
The package plugin.  Attempts to locate packages in Package managers for various operating systems.  Currently only supports debian.  Talk to simcop2387 about how to help get more added.
