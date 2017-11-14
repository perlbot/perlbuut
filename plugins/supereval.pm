# eval plugin for buubot3
package Bot::BB3::Plugin::Supereval;

use POE::Filter::Reference;
use IO::Socket::INET;
use Data::Dumper;
use App::EvalServerAdvanced::Protocol;
use Encode;
use DateTime::Event::Holiday::US;
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

  $self->{aliases} = [ qw/jseval jeval phpeval pleval perleval deparse swdeparse wsdeparse wdeparse sdeparse k20eval rbeval pyeval luaeval cpeval wscpeval swcpeval wcpeval scpeval/, @perl_aliases ];
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
  

  $resultstr =~ s/^(\x00)+//g;

  if (!$said->{captured} && length($resultstr) == 0) {
		$resultstr = "No output.";
	} elsif (!$said->{captured} && $resultstr !~ /\S/) {
    $resultstr = "\x{FEFF}$resultstr";
  }
  
  if ($type eq 'perl') {
      $self->{dbh}->do("INSERT INTO evals (input, output) VALUES (?, ?)", {}, $code, $resultstr);
  }

  my $holiday=get_holiday();

  my %special = (
               'Halloween' => {prob => 0.75, chars => ["\x{1F383}", "\x{1F47B}", "\x{1F480}", "\x{1F577}"]},
           'Christmas Eve' => {prob => 0.10, chars => ["\x{1F384}", "\x{1F385}"]},
               'Christmas' => {prob => 0.50, chars => ["\x{1F384}", "\x{1F385}"]},
              "Alaska Day" => {prob => 0.00, chars => []},
         "April Fools Day" => {prob => 0.00, chars => []},
            "Black Friday" => {prob => 0.10, chars => ["\x{1F4B8}", "\x{1F6D2}", "\x{1F6CD}"]},
        "Cesar Chavez Day" => {prob => 0.00, chars => []},
         "Citizenship Day" => {prob => 0.05, chars => ["\x{1F1FA}\x{1F1F8}"]},
            "Columbus Day" => {prob => 0.00, chars => []},
"Confederate Memorial Day" => {prob => 0.00, chars => []},
               "Earth Day" => {prob => 0.50, chars => ["\x{1F30E}", "\x{1F30D}", "\x{1F30F}"]},
            "Election Day" => {prob => 1.00, chars => ["\x{1F5F3}"]},
        "Emancipation Day" => {prob => 0.00, chars => []},
             "Fathers Day" => {prob => 0.00, chars => []},
                "Flag Day" => {prob => 0.00, chars => []}, # TODO all country flags
          "Fourth of July" => {prob => 1.00, chars => ["\x{1F1FA}\x{1F1F8}"]},
           "Groundhog Day" => {prob => 0.00, chars => []},
        "Independence Day" => {prob => 1.00, chars => ["\x{1F1FA}\x{1F1F8}"]},
     "Jefferson Davis Day" => {prob => 0.00, chars => []},
               "Labor Day" => {prob => 0.00, chars => []},
        "Leif Erikson Day" => {prob => 0.00, chars => []},
       "Lincolns Birthday" => {prob => 0.00, chars => []},
  "Martin Luther King Day" => {prob => 0.00, chars => []},
  "Martin Luther King Jr Birthday" => {prob => 0.00, chars => []},
            "Memorial Day" => {prob => 0.00, chars => []},
             "Mothers Day" => {prob => 0.00, chars => []},
           "New Years Day" => {prob => 0.00, chars => []},
           "New Years Eve" => {prob => 0.00, chars => []},
             "Patriot Day" => {prob => 0.00, chars => []},
    "Pearl Harbor Remembrance Day" => {prob => 0.00, chars => []},
          "Presidents Day" => {prob => 0.00, chars => []},
    "Primary Election Day" => {prob => 0.00, chars => []},
             "Sewards Day" => {prob => 0.00, chars => []},
        "St. Patricks Day" => {prob => 0.00, chars => []},
       "Super Bowl Sunday" => {prob => 0.00, chars => []},
    "Susan B. Anthony Day" => {prob => 0.00, chars => []},
            "Thanksgiving" => {prob => 1.00, chars => ["\x{1F983}"]},
        "Thanksgiving Day" => {prob => 1.00, chars => ["\x{1F983}"]},
          "Valentines Day" => {prob => 0.25, chars => ["\x{1F491}"]},
            "Veterans Day" => {prob => 0.00, chars => []},
    "Washingtons Birthday" => {prob => 0.00, chars => []},
    "Washingtons Birthday (observed)" => {prob => 0.00, chars => []},
         "Winter Solstice" => {prob => 0.00, chars => []},
     "Womens Equality Day" => {prob => 0.00, chars => []},
  );

  if ($special{$holiday}) {
    if (rand() < $special{$holiday}{prob}) {
      my $char = $special{$holiday}{chars}[rand()*@{$special{$holiday}{chars}}];

      $resultstr .= " ".$char;
    }
  }

	return( 'handled', $resultstr);
}

sub get_holiday {
  my $dt = DateTime->now(time_zone=>"PST8PDT")->truncate(to => 'day');

  my @known = DateTime::Event::Holiday::US::known();
  my $holidays = DateTime::Event::Holiday::US::holidays(@known);
  my $mass_set = DateTime::Event::Holiday::US::holidays_as_set(@known); # mass set of all of them
  if ($mass_set->contains($dt)) {
    # We're a holiday. do shit

    my $name = "";
    for my $key (@known) {
      if ($holidays->{$key}->contains($dt)) {
        $name = $key;
        last; # don't iterate more.
      }
    }

    return $name;
  }

  return "";
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
