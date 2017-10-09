# eval plugin for buubot3
package Bot::BB3::Plugin::Supereval;

use POE::Filter::Reference;
use IO::Socket::INET;
use Data::Dumper;
use App::EvalServerAdvanced::Protocol;
use Encode;
use strict;
use utf8;

no warnings 'void';

my @versions = ('', qw(1 2 3 4 5.0 5.1 5.2 5.3 5.4 5.5 5.6 5.8 5.10 5.12 5.14 5.16 5.18 5.20 5.22 5.24 5.26 all));

sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'eval';
	$self->{opts} = {
		command => 1,
	};

  my @perl_aliases = map {("eval$_", "weval$_", "seval$_", "wseval$_", "sweval$_")} @versions;

  $self->{aliases} = [ qw/jseval jeval phpeval pleval perleval deparse swdeparse wsdeparse wdeparse sdeparse k20eval rbeval pyeval luaeval/, @perl_aliases ];
    $self->{dbh} = DBI->connect("dbi:SQLite:dbname=var/evallogs.db");

	return $self;
}

sub command {
	my( $self, $said, $pm ) = @_;

	my $code = $said->{"body"};

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
		swdeparse => 'deparse',
		wsdeparse => 'deparse',
		wdeparse => 'deparse',
		sdeparse => 'deparse',
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
    'cp' => 'cperl',
    'swcp' => 'cperl',
    'wscp' => 'cperl',
    'wcp' => 'cperl',
    'scp' => 'cperl',
    map {($_=>"perl$_", "w$_"=>"perl$_", "s$_" => "perl$_", "ws$_"=>"perl$_", "sw$_"=>"perl$_")} @versions
	);

  my $orig_type = $type;
	$type = $translations{$type};
	if( not $type ) { $type = 'perl'; }
	warn "Found $type: $code";

  $code = eval {Encode::decode("utf8", $code)} // $code;

  if ($command =~ /^([ws]+)?(?:eval|deparse)/i) {
    my $c=$1;
    $code = "use warnings; ".$code if ($c =~ /w/);
    $code = "use strict; ".$code if ($c =~ /s/);
  }

  $code = "use utf8; ". $code if ($type =~ /^perl(5.(8|10|12|14|16|18|20|22|24|26))?$/);

  $code =~ s/␤/\n/g;
  
  my $resultstr='';
  
  unless ($type =~ /perlall/) {
    $resultstr = $self->do_singleeval($type, $code);
  } else {
    # TODO use channel config for this
    if ($said->{channel} eq '#perlbot' || $said->{channel} eq '*irc_msg') {
      $resultstr = $self->do_multieval([map {"perl".$_} grep {!/^(all|1|2|3|4|5\.5)$/} @versions], $code);
    } else {
      $resultstr = "evalall only works in /msg or in #perlbot";
    }
  }
  

  if (!$said->{captured} && $resultstr !~ /\S/) {
		$resultstr = "No output.";
	}
  
  if ($type eq 'perl') {
      $self->{dbh}->do("INSERT INTO evals (input, output) VALUES (?, ?)", {}, $code, $resultstr);
  }


	return( 'handled', $resultstr);
}

sub do_multieval {
  my ($self, $types, $code) = @_;


	my $socket = IO::Socket::INET->new(  PeerAddr => '192.168.32.1', PeerPort => '14401' )
		or die "error: cannot connect to eval server";

  my $seq = 1;
  my $output = '';

  for my $type (@$types) {
    my $eval_obj = {language => $type, files => [{filename => '__code', contents => $code, encoding => "utf8"}], prio => {pr_batch=>{}}, sequence => $seq++, encoding => "utf8"};
    print $socket encode_message(eval => $eval_obj); 
    my $message = $self->read_message($socket);
    # TODO error checking here
    $output .= sprintf "[[ %s ]]\n%s\n", $type, $message->get_contents;
  }


  return $output;
}

sub do_singleeval {
  my ($self, $type, $code) = @_;
	
	my $socket = IO::Socket::INET->new(  PeerAddr => '192.168.32.1', PeerPort => '14401' )
		or die "error: cannot connect to eval server";

  my $eval_obj = {language => $type, files => [{filename => '__code', contents => $code, encoding => "utf8"}], prio => {pr_realtime=>{}}, sequence => 1, encoding => "utf8"};

  $socket->autoflush();
  print $socket encode_message(eval => $eval_obj); 

  my $buf = '';
  my $data = '';
  my $resultstr = "Failed to read a message";

  my $message = $self->read_message($socket);

  if (ref($message) =~ /Warning$/) {
    return $message->message;
  } else {
    return $message->get_contents;
  }
}

sub read_message {
  my ($self, $socket) = @_;

  my $header;
  $socket->read($header, 8) or die "Couldn't read from socket";

  my ($reserved, $length) = unpack "NN", $header;

  die "Invalid packet" unless $reserved == 1;

  my $buffer;
  $socket->read($buffer, $length) or die "Couldn't read from socket2";

  my ($res, $message, $nbuf) = decode_message($header . $buffer);


  die "Data left over in buffer" unless $nbuf eq '';
  die "Couldn't decode packet" unless $res;

  return $message;
}

"Bot::BB3::Plugin::Supereval";

__DATA__
The eval plugin. Evaluates various different languages. Syntax, eval: code; also pleval deparse.  You can use different perl versions by doing eval5.X, e.g. eval5.5: print "$]";  You can also add s or w to the eval to quickly add strict or warnings.  sweval: print $foo;
