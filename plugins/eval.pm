# eval plugin for buubot3
package Bot::BB3::Plugin::Eval;

package Bot::BB3::Plugin::Eval;

use POE::Filter::Reference;
use IO::Socket::INET;
use Data::Dumper;
use Encode;
use strict;

no warnings 'void';

my @versions = ('', qw(5.5 5.6 5.8 5.10 5.12 5.14 5.16 5.18 5.20 5.22 5.24));

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'eval';
	$self->{opts} = {
		command => 1,
	};

  my @perl_aliases = map {("eval$_", "weval$_", "seval$_", "wseval$_", "sweval$_")} @versions;

  $self->{aliases} = [ qw/jseval jeval phpeval pleval perleval deparse k20eval rbeval pyeval luaeval/, @perl_aliases ];
    $self->{dbh} = DBI->connect("dbi:SQLite:dbname=var/evallogs.db");

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;

	my $code = $said->{"body"};
    my $dbh = $self->{dbh};

    my $command = $said->{command_match};
	my $type = $said->{command_match};
	$type =~ s/^\s*(\w+?)?eval(.*)?/$1$2/;
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
        's' => 'perl',
        'ws' => 'perl',
        'sw' => 'perl',
        map {($_=>"perl$_", "w$_"=>"perl$_", "s$_" => "perl$_", "ws$_"=>"perl$_", "sw$_"=>"perl$_")} @versions
	);

  my $orig_type = $type;
	$type = $translations{$type};
	if( not $type ) { $type = 'perl'; }
	warn "Found $type: $code";

    if ($command =~ /([ws]+)?eval/i) {
        my $c=$1;
        $code = "use warnings; ".$code if ($c =~ /w/);
        $code = "use strict; ".$code if ($c =~ /s/);
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
    chomp $resultstr;

    if (lc $resultstr eq "hello world" || lc $resultstr eq "hello, world!" ) {
        $resultstr .= " I'm back!"
    }

	return( 'handled', $resultstr);
}

"Bot::BB3::Plugin::Eval";

__DATA__
The eval plugin. Evaluates various different languages. Syntax, eval: code; also pleval deparse.  You can use different perl versions by doing eval5.X, e.g. eval5.5: print "$]";  You can also add s or w to the eval to quickly add strict or warnings.  sweval: print $foo;
