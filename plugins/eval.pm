# eval plugin for buubot3
package Bot::BB3::Plugin::Eval;

package Bot::BB3::Plugin::Eval;

use POE::Filter::Reference;
use IO::Socket::INET;
use Data::Dumper;
use Encode;
use strict;

no warnings 'void';

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'eval';
	$self->{opts} = {
		command => 1,
	};
	$self->{aliases} = [ qw/jseval jeval phpeval pleval perleval deparse k20eval rbeval pyeval luaeval weval/ ];
    $self->{dbh} = DBI->connect("dbi:SQLite:dbname=var/evallogs.db");

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;

	my $code = $said->{"body"};
    my $dbh = $self->{dbh};

    my $command = $said->{command_match};
	my $type = $said->{command_match};
	$type =~ s/^\s*(\w+?)eval/$1/;
	warn "Initial type: $type\n";
	my %translations = ( 
		js => 'javascript', 
		perl => 'perl',
		pl => 'perl',
		php => 'php',
		deparse => 'deparse',
		'k20' => 'k20',
		'k' => 'k20',
		'rb' => 'ruby',
		'ruby' => 'ruby',
		'py' => 'python',
		'python' => 'python',
		'lua' => 'lua',
		'j' => 'j',
        'w' => 'perl',
	);

	$type = $translations{$type};
	if( not $type ) { $type = 'perl'; }
	warn "Found $type: $code";

    if ($command eq 'weval') {
        $code = "use warnings; ".$code;
    }

    $code =~ s/␤/\n/g;

	my $filter = POE::Filter::Reference->new();
	my $socket = IO::Socket::INET->new(  PeerAddr => 'localhost', PeerPort => '14400' )
		or die "error: cannot connect to eval server";
	my $refs = $filter->put( [ { code => "$type $code" } ] );

	print $socket $refs->[0];

	local $/;
	my $output = <$socket>;
	$socket->close;

	my $result = $filter->get( [ $output ] );
	my $resultstr = $result->[0]->[0];

    if ($type eq 'perl') {
        $dbh->do("INSERT INTO evals (input, output) VALUES (?, ?)", {}, $code, $resultstr);
    }

	if (!$said->{captured} && $resultstr !~ /\S/) {
		$resultstr = "No output.";
	}

	$resultstr =~ s/\x0a?\x0d//g; # Prevent sending messages to the IRC server..

    $resultstr = decode("utf8", $resultstr);
    $resultstr =~ s/\0//g;
	
	return( 'handled', $resultstr );
}

"Bot::BB3::Plugin::Eval";

__DATA__
The eval plugin. Evaluates various different languages. Syntax, eval: code; also pleval deparse rbeval jseval pyeval phpeval k20eval luaeval jeval.
