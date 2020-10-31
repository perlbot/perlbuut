package Bot::BB3::Plugin::Factoids;

use v5.30;
use experimental 'signatures';
use feature 'postderef', 'fc';

use DBI;
use IRC::Utils qw/lc_irc strip_color strip_formatting/;
use Text::Metaphone;
use strict;
use Encode qw/decode/;
use JSON::MaybeXS qw/encode_json/;
use PPI; 
use PPI::Dumper; 

use Data::Dumper;
use List::Util qw/min max/;

open(my $fh, "<", "etc/factoid_db_keys") or die $!;
my ($dbname, $dbuser, $dbpass) = <$fh>;
close($fh);

chomp $dbname;
chomp $dbuser;
chomp $dbpass;

#############################
# BIG WARNING ABOUT THE DATABASE IN HERE.
#############################
#
# Despite the name 'original_subject' and 'subject' are logically reversed, e.g. 'original_subject' contains the cleaned up and filtered subject rather than the other way around.
# This should be kept in mind when working on any and all of the code below
#   --simcop2387 (previously also discovered by buu, but not documented or fixed).
#
# This might be fixed later but for now its easier to just "document" it. (boy doesn't this feel enterprisy!)
#
#############################

my $COPULA    = join '|', qw/is are was isn't were being am/, "to be", "will be", "has been", "have been", "shall be", "can has", "wus liek", "iz liek", "used to be";
my $COPULA_RE = qr/\b(?:$COPULA)\b/i;

#this is a hash that gives all the commands their names and functions, added to avoid some symbol table funkery that happened originally.
my %commandhash = (

    #	""          => \&get_fact, #don't ever add the default like this, it'll cause issues! i plan on changing that!
    "forget"     => \&get_fact_forget,
    "delete"     => \&get_fact_delete,
    "learn"      => \&get_fact_learn,
    "relearn"    => \&get_fact_learn,
    "literal"    => \&get_fact_literal,
    "revert"     => \&get_fact_revert,
    "revisions"  => \&get_fact_revisions,
    "search"     => \&get_fact_search,
    "oldsearch"  => \&get_fact_oldsearch,
    "protect"    => \&get_fact_protect,
    "unprotect"  => \&get_fact_unprotect,
    "substitute" => \&get_fact_substitute,
    "nchain"     => \&get_fact_namespace_chain,
    "factgrep"   => \&get_fact_grep,
);

my $commands_re = join '|', keys %commandhash;
$commands_re = qr/$commands_re/;

sub new($class) {
    my $self = bless {}, $class;
    $self->{name} = 'factoids';    # Shouldn't matter since we aren't a command
    $self->{opts} = {
        command => 1,
        handler => 1,
    };
    $self->{aliases} = [qw/fact call nfacts/];

    return $self;
}

sub dbh($self) {
    if ($self->{dbh} and $self->{dbh}->ping) {
        return $self->{dbh};
    }

    my $dbh = $self->{dbh} =
      DBI->connect("dbi:Pg:dbname=$dbname;host=192.168.32.1", $dbuser, $dbpass, { RaiseError => 1, PrintError => 0 });

    return $dbh;
}

sub get_namespace($self, $said) {
    my ($server, $channel) = $said->@{qw/server channel/};

    $server =~ s/^.*?([^\.]+\.[^\.]+)$/$1/;

    return ($server, $channel);
}

sub get_alias_namespace($self, $said) {
    my $conf = $self->get_conf_for_channel($said);

    my $server    = $conf->{alias_server}; 
    my $namespace = $conf->{alias_namespace}; 

    return ($server, $namespace);
}

sub get_conf_for_channel ($self, $said) {
    my ($server, $namespace) = $self->get_namespace($said);

    my $dbh = $self->dbh;

    my $result = $dbh->selectrow_hashref(qq{
      SELECT * FROM public.factoid_config WHERE server = ? AND namespace = ? LIMIT 1
    }, {}, $server, $namespace);

    my $conf = {
      server => '',
      namespace => '',
      alias_server => '',
      alias_namespace => '',
      parent_server => undef,
      parent_namespace => undef,
      recursive => 0,
      command_prefix => undef,

      %{$result//{}},
    };

    return $conf;
}

# TODO update this to use the new table layout once it's ready
sub postload {
    my ($self, $pm) = @_;

    # 	my $sql = "CREATE TABLE factoid (
    # 		factoid_id INTEGER PRIMARY KEY AUTOINCREMENT,
    # 		original_subject VARCHAR(100),
    # 		subject VARCHAR(100),
    # 		copula VARCHAR(25),
    # 		predicate TEXT,
    # 		author VARCHAR(100),
    # 		modified_time INTEGER,
    # 		metaphone TEXT,
    # 		compose_macro CHAR(1) DEFAULT '0',
    # 		protected BOOLEAN DEFAULT '0'
    # 	);
    #     CREATE INDEX factoid_subject_idx ON factoid(subject);
    #     CREATE INDEX factoid_original_subject_idx ON factoid(original_subject_idx);
    #     "; # Stupid lack of timestamp fields
    #
    # 	$pm->create_table( $self->dbh, "factoid", $sql );
    #
    # 	delete $self->{dbh}; # UGLY HAX GO.
    # Basically we delete the dbh we cached so we don't fork
    # with one active
}

# This whole code is a mess.
# Essentially we need to check if the user's text either matches a
# 'store command' such as "subject is predicate" or we need to check
# if it's a retrieve command such as "foo" or if it's a retrieve sub-
# command such as "forget foo"
# Need to add "what is foo?" support...
sub command ($self, $_said, $pm) {
    my $said = +{ $_said->%* };

    if ($said->{channel} eq '*irc_msg') {
        # Parse body here
        my $body = $said->{body};
        $said->{channel} = "##NULL" if $said->{channel} eq '*irc_msg';
    }
    
    if ($said->{body} =~ /^\s*(?<channel>#\S+)\s+(?<fact>.*)$/) {
        $said->{channel} = $+{channel};
        $said->{body} = $+{fact};
    }

    # TODO does this need to support parsing the command out again?

    my ($handled, $fact_out) = $self->sub_command($said, $pm);

    return ($handled, $fact_out);
}

sub sub_command ($self, $said, $pm) {
    return unless $said->{body} =~ /\S/;    #Try to prevent "false positives"

    my $call_only = $said->{command_match} eq "call";

    my $subject = $said->{body};

    my $commands_re = join '|', keys %commandhash;
    $commands_re = qr/$commands_re/;

    my $fact_string;                        # used to capture return values

    if (!$call_only && $subject =~ s/^\s*($commands_re)\s*//) {
        $fact_string =
          $commandhash{$1}->($self, $subject, $said->{name}, $said);
    } elsif ($subject =~ m{\w\s*=~\s*(s.*)$}ix)
    {
        $fact_string = $self->get_fact_substitute($subject, $said->{name}, $said);
    } elsif (!$call_only and $subject =~ /\s+$COPULA_RE\s+/) {
        return if $said->{nolearn};
        my @ret = $self->store_factoid($said);

        $fact_string = "Failed to store $said->{body}" unless @ret;

        $fact_string = "@ret" if ($ret[0] =~ /^insuff/i);
        $fact_string = "Stored @ret";
    } else {
        $fact_string = $self->get_fact($pm, $said, $subject, $said->{name}, $call_only);
    }

    if (defined $fact_string) {
        return ('handled', $fact_string);
    } else {
        return;
    }
}

# Handler code stolen from the old nfacts plugin
sub handle ($self, $said, $pm) {
    my $conf = $self->get_conf_for_channel($said);

    $said->{body} =~ s/^\s*(what|who|where|how|when|why)\s+($COPULA_RE)\s+(?<fact>.*?)\??\s*$/$+{fact}/i;

    my $prefix = $conf->{command_prefix};
    return unless $prefix;

    $said->{nosuggest} = 1;

    # TODO make this channel configurable and make it work properly to learn shit with colors later.
    $said->{body} = strip_formatting strip_color $said->{body};

    if (   $said->{body} =~ /^\Q$prefix\E(?<fact>[^@]*?)(?:\s@\s*(?<user>\S*)\s*)?$/
        || $said->{body} =~ /^\Q$prefix\E!@(?<user>\S+)\s+(?<fact>.+)$/)
    {
        my $fact = $+{fact};
        my $user = $+{user};

        my $newsaid = +{ $said->%* };
        $newsaid->{body} = $fact;

        if ($fact =~ /^\s*(?<channel>#\S+)\s+(?<fact>.*)$/) {
            my ($fact, $channel) = @+{qw/fact channel/};
            $newsaid->{body}    = $fact;
            $newsaid->{channel} = $channel;
        }

        $newsaid->{addressed} = 1;
        $newsaid->{nolearn}   = 1;

        my ($s, $r) = $self->command($newsaid, $pm);
        if ($s) {
            $r = "$user: $r" if $user;
            $r = "\0" . $r;
            return ($r, 'handled');
        }
    }

    return;
}

sub _clean_subject($subject) {
    $subject =~ s/^\s+//;
    $subject =~ s/\s+$//;
    $subject =~ s/\s+/ /g;

    #	$subject =~ s/[^\w\s]//g; #comment out to fix punct in factoids
    $subject = lc fc $subject;

    return $subject;
}

# TODO document this better
sub _clean_subject_func ($subject, $variant) {    # for parametrized macros
    my ($key, $arg);

    if ($variant) {
        $subject =~ /\A\s*(\S+(?:\s+\S+)?)(?:\s+(.*))?\z/s or return;

        ($key, $arg) = ($1, $2);

    } else {
        $subject =~ /\A\s*(\S+)(?:\s+(.*))?\z/s or return;

        ($key, $arg) = ($1, $2);
    }

    return $key, $arg;
}

sub store_factoid ($self, $said) {
    my ($self, $said) = @_;

    # alias namespace is the current alias we assign factoids to
    # server and namespace is the server and channel we're looking up for
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    my ($author, $body) = ($said->{name}, $said->{body});

    return unless $body =~ /^(?:no[, ])?\s*(.+?)\s+($COPULA_RE)\s+(.+)$/s;
    my ($subject, $copula, $predicate) = ($1, $2, $3);
    my $compose_macro = 0;

    return "Insufficient permissions for changing protected factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    if    ($subject =~ s/^\s*\@?macro\b\s*//) {$compose_macro = 1;}
    elsif ($subject =~ s/^\s*\@?func\b\s*//)  {$compose_macro = 2;}
    elsif ($predicate =~ s/^\s*also\s+//) {
        my $fact = $self->_db_get_fact(_clean_subject($subject), 0, $server, $namespace);

        $predicate = $fact->{predicate} . " | " . $predicate;
    }

    return
      unless $self->_insert_factoid($author, $subject, $copula, $predicate, $compose_macro, $self->_db_get_protect($subject, $server, $namespace), $aliasserver, $aliasnamespace);

    return ($subject, $copula, $predicate);
}

sub _insert_factoid ($self, $author, $subject, $copula, $predicate, $compose_macro, $protected, $server, $namespace, $deleted=0) {
    my $dbh = $self->dbh;

    warn "Attempting to insert factoid: type $compose_macro";

    my $key;
    if ($compose_macro == 2) {
        ($key, my $arg) = _clean_subject_func($subject, 1);
        warn "*********************** GENERATED [$key] FROM [$subject] and [$arg]\n";

        $arg =~ /\S/
          and return;
    } else {
        $key = _clean_subject($subject);
    }
    return unless $key =~ /\S/;

    $dbh->do(
        "INSERT INTO factoid 
		(original_subject,subject,copula,predicate,author,modified_time,metaphone,compose_macro,protected, namespace, server, deleted,last_rendered)
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        undef,
        $key,
        $subject,
        $copula,
        $predicate,
        lc_irc($author),
        time,
        Metaphone($key),
        $compose_macro || 0,
        $protected     || 0,
        $namespace,
        $server,
        $deleted,
        $predicate
    );

    # TODO trigger FTS update?

    return 1;
}

sub get_fact_protect ($self, $subject, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    warn "===TRYING TO PROTECT [$subject] [$name]\n";

    #XXX check permissions here
    return "Insufficient permissions for protecting factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    my $fact = $self->_db_get_fact(_clean_subject($subject), 0, $server, $namespace);

    if (defined($fact->{predicate})) {
        $self->_insert_factoid($name, $subject, $fact->{copula}, $fact->{predicate}, $fact->{compose_macro}, 1, $aliasserver, $aliasnamespace);

        return "Protected [$subject]";
    } else {
        return "Unable to protect nonexisting factoid [$subject]";
    }
}

sub get_fact_unprotect ($self, $subject, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    warn "===TRYING TO PROTECT [$subject] [$name]\n";

    #XXX check permissions here
    return "Insufficient permissions for unprotecting factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    my $fact = $self->_db_get_fact(_clean_subject($subject), 0, $server, $namespace);

    if (defined($fact->{predicate})) {
        $self->_insert_factoid($name, $subject, $fact->{copula}, $fact->{predicate}, $fact->{compose_macro}, 0, $aliasserver, $aliasnamespace);

        return "Unprotected [$subject]";
    } else {
        return "Unable to unprotect nonexisting factoid [$subject]";
    }
}

sub get_fact_forget ($self, $subject, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    warn "===TRYING TO FORGET [$subject] [$name]\n";

    #XXX check permissions here
    return "Insufficient permissions for forgetting protected factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    $self->_insert_factoid($name, $subject, "is", " ", 0, $self->_db_get_protect($subject, $server, $namespace), $aliasserver, $aliasnamespace);

    return "Forgot $subject";
}

sub get_fact_delete ($self, $subject, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    warn "===TRYING TO DELETE [$subject] [$name]\n";

    #XXX check permissions here
    return "Insufficient permissions for deleting protected factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    $self->_insert_factoid($name, $subject, "is", " ", 0, $self->_db_get_protect($subject, $server, $namespace), $aliasserver, $aliasnamespace, 1);

    return "Deleted $subject from $server:$namespace";
}

sub _fact_literal_format($r, $aliasserver, $aliasnamespace) {
    $aliasserver ||= "*";
    $aliasnamespace ||= "##NULL";
    # TODO make this express the parent namespace if present
    # <server:namespace>
    #
    
    (($aliasserver eq ($r->{generated_server}||"*") && $aliasnamespace eq ($r->{generated_namespace}||"##NULL")) ? "" : sprintf("<%s:%s> ", $r->{generated_server}||"*", $r->{generated_namespace}||"##NULL")) 
    . ($r->{deleted} ? "[REDACTED]" :
      (
        ($r->{protected} ? "P:" : "") 
      . ("", "macro ", "func ")[$r->{compose_macro}] 
      . "$r->{subject} $r->{copula} $r->{predicate}"
    ));
}

sub get_fact_revisions ($self, $subject, $name, $said) {
    my $dbh = $self->dbh;

    my ($server, $namespace) = $self->get_namespace($said);
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);

    # TODO this query should use the deleted flag to figure out
    # which depth lookup should be valid at any given time
    # but that's a much more complicated query i don't want to make
    # maybe just do it in perl later
    my $revisions = $dbh->selectall_arrayref("
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE original_subject = ?
      ORDER BY depth ASC, factoid_id DESC
)
SELECT * FROM get_latest_factoid ORDER BY factoid_id DESC;
		",    # newest revision first
        { Slice => {} },
        $namespace, $server,
        _clean_subject($subject),
    );

    my $ret_string = join " \n", map {"[$_->{factoid_id} by $_->{author}: " . _fact_literal_format($_, $aliasserver, $aliasnamespace) . "]";} @$revisions;

    return $ret_string;
}

sub get_fact_literal ($self, $subject, $name, $said) {
    my ($server, $namespace) = $self->get_namespace($said);
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);

    print STDERR "literal parse: $subject, $name, $server, $namespace\n";
    my $fact = $self->_db_get_fact(_clean_subject($subject), 0, $server, $namespace);
    print STDERR "literal fact: ".Dumper($fact)."\n";

    my $formatted = _fact_literal_format($fact, $aliasserver, $aliasnamespace);
    print STDERR "formatted: $formatted\n";
    return $formatted;
}

sub _fact_substitute ($self, $pred, $match, $subst, $flags) {
    if ($flags =~ /g/) {
        my $regex = $flags =~ /i/ ? qr/(?i:$match)/i : qr/$match/;

        while ($pred =~ /$regex/g) {
            my $matchedstring = substr($pred, $-[0], $+[0] - $-[0]);
            my ($matchstart, $matchend) = ($-[0], $+[0]);
            my @caps =
              map {substr($pred, $-[$_], $+[$_] - $-[$_])} 1 .. $#+;
            my $realsubst = $subst;
            $realsubst =~ s/(?<!\\)\$(?:\{(\d+)\}|(\d+))/$caps[$1-1]/eg;
            $realsubst =~ s/\\(?=\$)//g;

            substr $pred, $matchstart, $matchend - $matchstart, $realsubst;
            pos $pred = $matchstart + length($realsubst);    #set the new position, might have an off by one?
        }

        return $pred;
    } else {
        my $regex = $flags =~ /i/ ? qr/(?i:$match)/i : qr/$match/;

        if ($pred =~ /$regex/) {
            my @caps =
              map {substr($pred, $-[$_], $+[$_] - $-[$_])} 1 .. $#+;
            my $realsubst = $subst;
            $realsubst =~ s/(?<!\\)\$(?:\{(\d+)\}|(\d+))/$caps[$1-1]/eg;
            $realsubst =~ s/\\(?=\$)//g;

            $pred =~ s/$regex/$realsubst/;
        }

        return $pred;
    }
}

sub get_fact_substitute ($self, $subject, $name, $said) {

    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    #    my $m = $said->{body} =~ m{^(?:\s*substitute)?\s*(.*?)\s*=~\s*(s.*)$}ix;
    #return $said->{body} . "$m $1 $2";

    if ($said->{body} =~ m{^(?:\s*substitute)?\s*(.*?)\s*=~\s*(s.*)$}ix)
    {
        my ($subject, $regex) = ($1, $2);
        my $pdoc = PPI::Document->new(\$regex);
        return "Failed to parse $regex" unless $pdoc;

        # TODO handle tr|y///
        my $token = $pdoc->find(sub {$_[1]->isa('PPI::Token::Regexp::Substitute')})->[0];

        return "Couldn't find s/// in $regex" unless $token;

        my $match = $token->get_match_string;
        my $subst = $token->get_substitute_string;
        my $flags = join '', keys +{$token->get_modifiers()}->%*;

        # TODO does this need to be done via the ->get_fact() instead now?
        my $fact = $self->_db_get_fact(_clean_subject($subject), 0, $server, $namespace);

        if ($fact && $fact->{predicate} =~ /\S/) {    #we've got a fact to operate on
            if ($match !~ /(?:\(\?\??\{)/) {          #ok, match has checked out to be "safe", this will likely be extended later
                my $pred = $fact->{predicate};
                my $result;

                #moving this to its own function for cleanliness
                $result = $self->_fact_substitute($pred, $match, $subst, $flags);

                # TODO why is this calling there?
                # let this fail for now
                my $ret = $self->get_fact_learn("learn $subject as $result", $name, $said, $subject, $result);

                return $ret;
            } else {
                return "Can't use dangerous things in a regex, you naughty user";
            }
        } else {
            return "Can't substitute on unknown factoid [$subject]";
        }
    }
}

sub get_fact_revert ($self, $subject, $name, $said) {
    my $dbh = $self->dbh;

    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    #XXX check permissions here
    return "Insufficient permissions for reverting protected factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    $subject =~ s/^\s*(\d+)\s*$//
      or return "Failed to match revision format";
    my $rev_id = $1;

    my $fact_rev = $dbh->selectrow_hashref(
        "SELECT subject, copula, predicate, compose_macro
		FROM factoid
		WHERE factoid_id = ?",
        undef,
        $rev_id
    );

    my $protect = $self->_db_get_protect($fact_rev->{subject}, $server, $namespace);

    return "Bad revision id"
      unless $fact_rev and $fact_rev->{subject};    # Make sure it's valid..

    #                        subject, copula, predicate
    $self->_insert_factoid($name, @$fact_rev{qw"subject copula predicate compose_macro"}, $protect, $aliasserver, $aliasnamespace);

    return "Reverted $fact_rev->{subject} to revision $rev_id";
}

sub get_fact_learn ($self, $body, $name, $said, $subject=undef, $predicate=undef) {

    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    return if ($said->{nolearn});

    $body =~ s/^\s*learn\s+//;

    my $copula = "is";
    unless ($subject && $predicate) {
      ($subject, $copula, $predicate) = $body =~ /^\s*(.*?)\s+(as|$COPULA_RE)\s+(.*)\s*$/ig;
    }

    #XXX check permissions here
    return "Insufficient permissions for changing protected factoid [$subject]"
      if (!$self->_db_check_perm($subject, $said));

    #my @ret = $self->store_factoid( $name, $said->{body} );
    $self->_insert_factoid($name, $subject, $copula, $predicate, 0, $self->_db_get_protect($subject, $server, $namespace), $aliasserver, $aliasnamespace);

    return "Stored $subject as $predicate";
}

sub get_fact_search($self, $body, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    $body =~ s/^\s*for\s*//;    #remove the for from searches


    my $results = $self->dbh->selectall_arrayref(" 
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_factoid_search (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace, full_document_tsvector, last_rendered) AS (
      SELECT DISTINCT ON (original_subject) lo.depth, factoid_id, subject, 
        copula, predicate, author, modified_time, compose_macro, protected, 
        original_subject, f.deleted, f.server, f.namespace, f.full_document_tsvector, f.last_rendered
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE NOT deleted
      ORDER BY original_subject ASC, depth ASC, factoid_id DESC
)
SELECT ts_rank(full_document_tsvector, websearch_to_tsquery('factoid', ?)) AS rank, * FROM get_factoid_search WHERE ts_rank(full_document_tsvector, websearch_to_tsquery('factoid', ?)) > 0.01 ORDER BY 1 DESC, factoid_id DESC LIMIT 10
      ",
            { Slice => {} },
            $namespace, $server,
            $body, $body
        );

    if ($results and @$results) {
        my $ret_string;
        for (@$results) {

            #i want a better string here, i'll probably go with just the subject, XXX TODO
            $ret_string .= "[" . _fact_literal_format($_, $aliasserver, $aliasnamespace) . "]\n"
              if ($_->{predicate} !~ /^\s*$/);
        }

        return $ret_string;
    } else {
        return "No matches.";
    }


}

sub get_fact_namespace_chain ($self, $body, $name, $said) {
    local $said->{channel} = $said->{channel};
    if ($body) {
      $said->{channel} = $body;
    }

    my ($server,      $namespace)      = $self->get_namespace($said);
    print STDERR "XXX: $body $said->{channel} $server $namespace\n";

    #XXX: need to also search contents of factoids TODO
    my $results = $self->dbh->selectall_arrayref(" 
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
)
SELECT depth, namespace, server FROM factoid_lookup_order_inner
", { Slice => {} }, $namespace, $server);

  print STDERR "XXX: $body $said->{channel} $server $namespace\n";
  print STDERR Dumper($results);

   my $return = join ' -> ', map {sprintf "%d. <%s:%s>", $_->{depth}+1, $_->{server}||"*", $_->{namespace}||"##NULL"} $results->@*;

   $return ||= "<$server:$namespace>"; # default namespace display
   return $return;
}

sub get_fact_grep ($self, $body, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    my $results;

    my $value_only = $body =~ s/\s*--val\s+//;

    $results = $self->dbh->selectall_arrayref(" 
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE original_subject ~* ?
      ORDER BY depth ASC, factoid_id DESC
)
SELECT DISTINCT ON(original_subject) original_subject, predicate FROM get_latest_factoid WHERE NOT deleted ORDER BY original_subject ASC, depth ASC, factoid_id DESC",
        { Slice => {} },
        $namespace, $server,
        $body,
    );

    print STDERR "Got results: ".Dumper($results);

    if ($results and @$results) {
        my $ret_string = encode_json([map {$value_only ? $_->{predicate} : $_->{original_subject}} @$results]); 

        return $ret_string;
    } else {
        return "[]";
    }

}

sub get_fact_oldsearch ($self, $body, $name, $said) {
    my ($aliasserver, $aliasnamespace) = $self->get_alias_namespace($said);
    my ($server,      $namespace)      = $self->get_namespace($said);

    $body =~ s/^\s*for\s*//;    #remove the for from searches

    my $results;

    if ($body =~ m|^\s*m?/(.*)/\s*$|) {
        my $search = $1;
        print STDERR "Got regex, $search\n";

        #XXX: need to also search contents of factoids TODO
        $results = $self->dbh->selectall_arrayref(" 
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE original_subject ~* ? OR predicate ~* ?
      ORDER BY depth ASC, factoid_id DESC
)
SELECT DISTINCT ON(original_subject) * FROM get_latest_factoid WHERE NOT deleted ORDER BY original_subject ASC, depth ASC, factoid_id DESC",
            { Slice => {} },
            $namespace, $server,
            $search, $search,
        );
    } else {
        print STDERR "No regex found, searching $body\n";
        #XXX: need to also search contents of factoids TODO
        $results = $self->dbh->selectall_arrayref("
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE original_subject ILIKE ? OR predicate ILIKE ?
      ORDER BY depth ASC, factoid_id DESC
)
SELECT DISTINCT ON(original_subject) * FROM get_latest_factoid WHERE NOT deleted ORDER BY original_subject ASC, depth ASC, factoid_id DESC",
            { Slice => {} },
            $namespace, $server,
            "%$body%", "%$body%",
        );
    }

    print STDERR "Got results: ".Dumper($results);

    if ($results and @$results) {
        my $ret_string;
        for (@$results) {

            #i want a better string here, i'll probably go with just the subject, XXX TODO
            $ret_string .= "[" . _fact_literal_format($_, $aliasserver, $aliasnamespace) . "]\n"
              if ($_->{predicate} !~ /^\s*$/);
        }

        return $ret_string;
    } else {
        return "No matches.";
    }

}

sub get_fact ($self, $pm, $said, $subject, $name, $call_only) {
    return $self->basic_get_fact($pm, $said, $subject, $name, $call_only);
}

sub _db_check_perm ($self, $subj, $said) {
    my ($server, $namespace) = $self->get_namespace($said);

    print STDERR "inside check perm\n";
    my $isprot = $self->_db_get_protect($subj, $server, $namespace);

    warn "Checking permissions of [$subj] for [$said->{name}]";
    warn Dumper($said);

    #always refuse to change factoids if not in one of my channels
    return 0 if (!$said->{in_my_chan});

    #if its not protected no need to check if they are op or root;
    return 1 if (!$isprot);

    if ($isprot && ($said->{by_root} || $said->{by_chan_op})) {
        return 1;
    }

    #default case, $isprotect true; op or root isn't
    return 0;
}

#get the status of the protection bit
sub _db_get_protect ($self, $subj, $server, $namespace) {
    $subj = _clean_subject($subj);

    my $dbh  = $self->dbh;
    my $prot = (
        $dbh->selectrow_array("
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT DISTINCT ON(lo.depth) lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE original_subject = ?
      ORDER BY depth ASC, factoid_id DESC
)
SELECT protected FROM get_latest_factoid WHERE NOT deleted ORDER BY depth ASC, factoid_id DESC LIMIT 1;
                ",
            undef,
            $namespace, $server,
            $subj,
        )
    )[0];

    return $prot;
}

sub _db_get_fact ($self, $subj, $func, $server, $namespace) {

    # TODO write the recursive CTE for this

    my $dbh  = $self->dbh;
    my $fact = $dbh->selectrow_hashref("
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT DISTINCT ON(lo.depth) lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE original_subject = ?
      ORDER BY depth ASC, factoid_id DESC
)
SELECT * FROM get_latest_factoid WHERE NOT deleted ORDER BY depth ASC, factoid_id DESC LIMIT 1;
      ",
        undef,
        $namespace, $server,
        $subj,
    );

    if ($func && (!$fact->{compose_macro})) {
        return undef;
    } else {
        return $fact;
    }
}

sub basic_get_fact ($self, $pm, $said, $subject, $name, $call_only) {
    my ($server,      $namespace)      = $self->get_namespace($said);
    
    #  open(my $fh, ">>/tmp/facts");
    my ($fact, $key, $arg);
    $key = _clean_subject($subject);

    if (!$call_only) {
        $fact = $self->_db_get_fact($key, 0, $server, $namespace);
    }

    # Attempt to determine if our subject matches a previously defined
    # 'macro' or 'func' type factoid.
    # I suspect it won't match two word function names now.

    for my $variant (0, 1) {
        if (!$fact) {
            ($key, $arg) = _clean_subject_func($subject, $variant);
            $fact = $self->_db_get_fact($key, 1, $server, $namespace);
        }
    }

    if ($fact->{predicate} =~ /\S/) {
        if ($fact->{compose_macro}) {
            my $plugin = $pm->get_plugin("compose", $said);

            local $said->{macro_arg} = $arg;
            local $said->{body}      = $fact->{predicate};
            local $said->{addressed} = 1;                    # Force addressed to circumvent restrictions? May not be needed!

            open(my $fh, ">/tmp/wutwut");
            print $fh Dumper($said, $plugin, $pm);

            my $ret = $plugin->command($said, $pm);
            use Data::Dumper;
            print $fh Dumper({ key => $key, arg => $arg, fact => $fact, ret => $ret });

            $self->set_last_rendered($fact, $ret);

            $ret = "\x00$ret" if ($key eq "tell");

            return $ret;
        } else {
            return "$fact->{predicate}";
        }
    } else {
        if ($subject =~ /[\?\.\!]$/)
        #check if some asshole decided to add a ? at the end of the factoid, if so remove it and recurse, this should only be able to recurse N times so it should be fine
        {
            my $newsubject = $subject;
            $newsubject =~ s/[\?\.\!]$//;
            return $self->basic_get_fact($pm, $said, $newsubject, $name, $call_only);
        }

        print STDERR "Got to here\n";
        my $matches = $self->get_suggestions($key, $server, $namespace);

        push @{ $said->{suggestion_matches} }, @$matches;

        if (!$said->{nosuggest} && ($matches and @$matches) && (!$said->{backdressed})) {
            return "No factoid found. Did you mean one of these: " . join " ", map "[$_]", @$matches;
        } else {
            return;
        }
    }
}

sub get_suggestions($self, $subject, $server, $namespace) {
    my $dbh = $self->dbh;

    print STDERR "Running search for $subject\n";
    my $threshold = 0.2;

    # TODO this should be using the trigram stuff once it's ready
    my $rows = $dbh->selectall_arrayref("
WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = ? AND server = ?
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_factoid_trigram (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace, similarity) AS (
      SELECT DISTINCT ON (lo.depth, original_subject) lo.depth, factoid_id, subject, 
        copula, predicate, author, modified_time, compose_macro, protected, 
        original_subject, f.deleted, f.server, f.namespace, 
        (difference(original_subject, ?) ::float + similarity(?, original_subject)) / greatest(length(?), length(original_subject))
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE (difference(original_subject, ?) ::float + similarity(?, original_subject)) / greatest(length(?), length(original_subject)) > ?
      ORDER BY depth ASC, original_subject ASC, factoid_id DESC
),
folddown AS (SELECT DISTINCT ON (similarity, original_subject) similarity, factoid_id, original_subject, predicate FROM get_factoid_trigram WHERE NOT deleted ORDER BY similarity DESC, original_subject, depth, factoid_id DESC)
SELECT * FROM folddown WHERE predicate ~ '\\S' AND predicate IS NOT NULL LIMIT 10
      ", undef, 
$namespace, $server,
$subject, $subject, $subject, $subject, $subject, $subject, $threshold
    );
   
    print STDERR Dumper($rows);

    return [grep {$_} map {$_->[2]} @$rows ];
}

sub set_last_rendered($self, $fact, $ret) {
  my $factoid_id = $fact->{factoid_id};

  my $dbh = $self->dbh;

  $dbh->do("UPDATE factoid SET last_rendered = ? WHERE factoid_id = ?", undef,
  $ret, $factoid_id
  );

  # TODO trigger FTS update?
}


no warnings 'void';
"Bot::BB3::Plugin::Factoids";
__DATA__
Learn or retrieve persistent factoids. "foo is bar" to store. "foo" to retrieve. try "forget foo" or "revisions foo" or "literal foo" or "revert $REV_ID" too. "macro foo is [echo bar]" or "func foo is [echo bar [arg]]" for compose macro factoids. The factoids/fact/call keyword is optional except in compose. Search <subject> to search for factoids that match.
