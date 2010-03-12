package Bot::BB3::Plugin::Factoids;
use DBI;
use DBD::SQLite;
use POE::Component::IRC::Common qw/l_irc/;
use Text::Soundex qw/soundex/;
use strict;

use Data::Dumper;

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

my $COPULA = join '|', qw/is are was isn't were being am/, "to be", "will be", "has been", "have been", "shall be", "can has", "wus liek", "iz liek", "used to be";
my $COPULA_RE = qr/\b(?:$COPULA)\b/i;

#this is a hash that gives all the commands their names and functions, added to avoid some symbol table funkery that happened originally.
my %commandhash = (
#	""          => \&get_fact, #don't ever add the default like this, it'll cause issues! i plan on changing that!
	"forget"    => \&get_fact_forget,
	"learn"     => \&get_fact_learn,
	"relearn"   => \&get_fact_learn,
	"literal"   => \&get_fact_literal,
	"revert"    => \&get_fact_revert,
	"revisions" => \&get_fact_revisions,
	"search"    => \&get_fact_search,
	"protect"   => \&get_fact_protect,
	"unprotect" => \&get_fact_unprotect,
	"substitute"=> \&get_fact_substitute,
	);


sub new {
	my( $class ) = @_;

	my $self = bless {}, $class;
	$self->{name} = 'factoids'; # Shouldn't matter since we aren't a command
	$self->{opts} = {
		command => 1,
		#handler => 1,
	};
	$self->{aliases} = [ qw/fact call/ ];

	return $self;
}

sub dbh { 
	my( $self ) = @_;
	
	if( $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = $self->{dbh} = DBI->connect(
		"dbi:SQLite:dbname=var/factoids.db",
		"",
		"",
		{ RaiseError => 1, PrintError => 0 }
	);

	return $dbh;
}

sub postload {
	my( $self, $pm ) = @_;


	my $sql = "CREATE TABLE factoid (
		factoid_id INTEGER PRIMARY KEY AUTOINCREMENT,
		original_subject VARCHAR(100),
		subject VARCHAR(100),
		copula VARCHAR(25),
		predicate TEXT,
		author VARCHAR(100),
		modified_time INTEGER,
		soundex VARCHAR(4),
		compose_macro CHAR(1) DEFAULT '0',
		protected BOOLEAN DEFAULT '0'
	)"; # Stupid lack of timestamp fields

	$pm->create_table( $self->dbh, "factoid", $sql );

	delete $self->{dbh}; # UGLY HAX GO.
	                     # Basically we delete the dbh we cached so we don't fork
											 # with one active
}

# This whole code is a mess.
# Essentially we need to check if the user's text either matches a 
# 'store command' such as "subject is predicate" or we need to check
# if it's a retrieve command such as "foo" or if it's a retrieve sub-
# command such as "forget foo"
# Need to add "what is foo?" support...
sub command {
	my( $self, $said, $pm ) = @_;
	
	return unless $said->{body} =~ /\S/; #Try to prevent "false positives"
	
	my $call_only = $said->{command_match} eq "call";

	my $subject = $said->{body};
	
	if( !$call_only and $subject =~ /\s+$COPULA_RE\s+/ ) { 
		my @ret = $self->store_factoid( $said ); 

		return( 'handled', "Failed to store $said->{body}" )
		unless @ret;

		return ('handled', "@ret") if ($ret[0] =~ /^insuff/i);
		return( 'handled', "Stored @ret" );
	}
	else {
		my $commands_re = join '|', keys %commandhash;
		   $commands_re = qr/$commands_re/;

		my $fact_string;

		if( !$call_only && $subject =~ s/^\s*($commands_re)\s+// ) {
			#i lost the object oriented calling here, but i don't care too much, BECAUSE this avoids using strings for the calling, i might change that.
			$fact_string = $commandhash{$1}->($self,$subject, $said->{name}, $said);
		}
		else {
			$fact_string = $self->get_fact( $pm, $said, $subject, $said->{name}, $call_only );
		}
		if( $fact_string ) {
			return( 'handled', $fact_string );
		}
		else {
			return;
		}
	}
}

sub _clean_subject {
	my( $subject ) = @_;

	$subject =~ s/^\s+//;
	$subject =~ s/\s+$//;
	$subject =~ s/\s+/ /g;
#	$subject =~ s/[^\w\s]//g; #comment out to fix punct in factoids
	$subject = lc $subject;

	return $subject;
}

sub _clean_subject_func { # for parametrized macros
	my($subject, $variant) = @_;
	my( $key, $arg );

	if ($variant) {
		$subject =~ /\A\s*(\S+(?:\s+\S+)?)(?:\s+(.*))?\z/s or return;
		
		( $key, $arg ) = ( $1, $2 );

	} else {
		$subject =~ /\A\s*(\S+)(?:\s+(.*))?\z/s or return;

		( $key, $arg ) = ( $1, $2 );
	}
	$key =~ s/[^\w\s]//g;

	return $key, $arg;
}

sub store_factoid {
	my( $self, $said) =@_;
	my ($author, $body ) = ($said->{name}, $said->{body});

	return unless $body =~ /^\s*(.+?)\s+($COPULA_RE)\s+(.+)$/s;
	my( $subject, $copula, $predicate ) = ($1,$2,$3);
	my $compose_macro = 0;

	return "Insufficient permissions for changing protected factoid [$subject]" if (!$self->_db_check_perm($subject,$said));

	if( $subject =~ s/^\s*\@?macro\b\s*// ) { $compose_macro = 1; }
	elsif( $subject =~ s/^\s*\@?func\b\s*// ) { $compose_macro = 2; }
	elsif( $predicate =~ s/^\s*also\s+// ) {
		my $fact = $self->_db_get_fact( _clean_subject( $subject ), $author );
		
		$predicate = $fact->{predicate} . " " .  $predicate;
	}
	
	return unless
		$self->_insert_factoid( $author, $subject, $copula, $predicate, $compose_macro, $self->_db_get_protect($subject) );

	return( $subject, $copula, $predicate );
}

sub _insert_factoid {
	my( $self, $author, $subject, $copula, $predicate, $compose_macro, $protected ) = @_;
	my $dbh = $self->dbh;

	warn "Attempting to insert factoid: type $compose_macro";

	my $key;
	if ( $compose_macro == 2 ) {
		($key, my $arg) = _clean_subject_func($subject, 1);
		warn "*********************** GENERATED [$key] FROM [$subject] and [$arg]\n";

		$arg =~ /\S/ 
			and return;
	}
	else {
		$key = _clean_subject( $subject );
	}
	return unless $key =~ /\S/;

	$dbh->do( "INSERT INTO factoid 
		(original_subject,subject,copula,predicate,author,modified_time,soundex,compose_macro,protected)
		VALUES (?,?,?,?,?,?,?,?,?)",
		undef,
		$key,
		$subject,
		$copula,
		$predicate,
		l_irc($author),
		time,
		soundex($key),
		$compose_macro || 0,
		$protected || 0,
	);

	return 1;
}

sub get_fact_protect {
	my( $self, $subject, $name, $said ) = @_;

	warn "===TRYING TO PROTECT [$subject] [$name]\n";

	#XXX check permissions here
	return "Insufficient permissions for protecting factoid [$subject]" if (!$self->_db_check_perm($subject,$said));

	my $fact = $self->_db_get_fact( _clean_subject( $subject ), $name );

	if (defined($fact->{predicate}))
	{
		$self->_insert_factoid( $name, $subject, $fact->{copula}, $fact->{predicate}, $fact->{compose_macro}, 1 );

		return "Protected [$subject]";
	}
	else
	{
		return "Unable to protect nonexisting factoid [$subject]";
	}
}

sub get_fact_unprotect {
	my( $self, $subject, $name, $said ) = @_;

	warn "===TRYING TO PROTECT [$subject] [$name]\n";

	#XXX check permissions here
	return "Insufficient permissions for unprotecting factoid [$subject]" if (!$self->_db_check_perm($subject,$said));

	my $fact = $self->_db_get_fact( _clean_subject( $subject ), $name );
	
	if (defined($fact->{predicate}))
        {
                $self->_insert_factoid( $name, $subject, $fact->{copula}, $fact->{predicate}, $fact->{compose_macro}, 0 );
        
                return "Unprotected [$subject]";
        }
        else
        {
                return "Unable to unprotect nonexisting factoid [$subject]";
        }
}

sub get_fact_forget {
	my( $self, $subject, $name, $said ) = @_;

	warn "===TRYING TO FORGET [$subject] [$name]\n";

	#XXX check permissions here
	return "Insufficient permissions for forgetting protected factoid [$subject]" if (!$self->_db_check_perm($subject,$said));

	$self->_insert_factoid( $name, $subject, "is", " ", 0, $self->_db_get_protect($subject) );

	return "Forgot $subject";
}

sub _fact_literal_format {
	my($r) = @_;
	($r->{protected}?"P:" : "" ).
                ("","macro ","func ")[$r->{compose_macro}] . 
		"$r->{subject} $r->{copula} $r->{predicate}";
}

sub get_fact_revisions {
	my( $self, $subject, $name ) = @_;
	my $dbh = $self->dbh;

	my $revisions = $dbh->selectall_arrayref(
		"SELECT factoid_id, subject, copula, predicate, author, compose_macro, protected 
			FROM factoid
			WHERE original_subject = ?
			ORDER BY modified_time DESC
		", # newest revision first
		{Slice=>{}},
		_clean_subject( $subject ),
	);

	my $ret_string = join " ", map {
		"[$_->{factoid_id} by $_->{author}: " . _fact_literal_format($_) . "]";
	} @$revisions;

	return $ret_string;
}

sub get_fact_literal {
	my( $self, $subject, $name ) = @_;

	my $fact = $self->_db_get_fact( _clean_subject( $subject ), $name );

	return _fact_literal_format($fact);
}

sub _fact_substitute_global
{
}

sub _fact_substitute
{
	my ($self, $pred, $match, $subst, $flags) = @_;
	
	if ($flags =~ /g/)
	{
		my $regex = $flags=~/i/ ? qr/(?i:$match)/i : qr/$match/;
		
		while ($pred =~ /\G$regex/g)
		{
			my $matchedstring = substr($pred, $-[0], $+[0] - $-[0]);
			my ($matchstart, $matchend) = ($-[0], $+[0]);
			my @caps = map {substr($pred, $-[$_], $+[$_] - $-[$_])} 1..$#+;
			my $realsubst = $subst;
			$realsubst =~ s/\$(\d+)/$caps[$1-1]/eg;
			
			substr $pred, $matchstart, $matchend-$matchstart, $realsubst;
			pos $pred = $matchstart+length($realsubst); #set the new position, might have an off by one?
		}
		
		return "$pred";
	}
	else
	{
		my $regex = $flags=~/i/ ? qr/(?i:$match)/i : qr/$match/;
		
		if ($pred =~ /$regex/)
		{
			my @caps = map {substr($pred, $-[$_], $+[$_] - $-[$_])} 1..$#+;
			my $realsubst = $subst;
			$realsubst =~ s/\$(\d+)/$caps[$1-1]/eg;
			
			$pred =~ s/$regex/$realsubst/;
			
			return $pred;
		}
		else
		{
			return "O:$regex:$flags:$match:$subst:".$pred;
		}		
	}
}

sub get_fact_substitute {
	my( $self, $subject, $name, $said ) = @_;

	if ($said->{body} =~ m|^(?:\s*substitute)?\s*(.*?)\s*=~\s*s/([^/]+)/([^/]+)/([gi]*)\s*$|i)
	{
		my ($subject, $match, $subst, $flags) = ($1, $2, $3, $4);
		
		my $fact = $self->_db_get_fact( _clean_subject( $subject ), $name );
		
		if ($fact && $fact->{predicate} =~ /\S/)
		{ #we've got a fact to operate on
			if ($match !~ /(?:\(\?\??\{)/)
			{ #ok, match has checked out to be "safe", this will likely be extended later
				my $pred = $fact->{predicate};
				my $result;

				#moving this to its own function for cleanliness				
				$result = $self->_fact_substitute($pred, $match, $subst, $flags);
				
				return "Result was, [$result]";				
			}
			else
			{
				return "Can't use dangerous things in a regex, you naughty user you";
			}
		}
		else
		{
			return "Can't substitute on unknown factoid [$subject]";
		}
	}
}

sub get_fact_revert {
	my( $self, $subject, $name, $said ) = @_;
	my $dbh = $self->dbh;

	#XXX check permissions here
	return "Insufficient permissions for reverting protected factoid [$subject]" if (!$self->_db_check_perm($subject,$said));

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

	my $protect = $self->_db_get_protect($fact_rev->{subject});

	return "Bad revision id" unless $fact_rev and $fact_rev->{subject}; # Make sure it's valid..

	#                        subject, copula, predicate
	$self->_insert_factoid( $name, @$fact_rev{qw"subject copula predicate compose_macro"}, $protect);

	return "Reverted $fact_rev->{subject} to revision $rev_id";
}

sub get_fact_learn {
	my( $self, $body, $name, $said ) = @_;

	$body =~ s/^\s*learn\s+//;
	my( $subject, $predicate ) = split /\s+as\s+/, $body, 2;

	#XXX check permissions here
	return "Insufficient permissions for changing protected factoid [$subject]" if (!$self->_db_check_perm($subject,$said));

	#my @ret = $self->store_factoid( $name, $said->{body} ); 
	$self->_insert_factoid( $name, $subject, 'is', $predicate, 0 , $self->_db_get_protect($subject));

	return "Stored $subject as $predicate";
}

sub get_fact_search {
	my( $self, $body, $name ) = @_;

	$body =~ s/^\s*for\s*//; #remove the for from searches

    my $results;

    if ($body =~ m|^\s*m?/(.*)/\s*$|) 
    {
    	my $search = $1;
		#XXX: need to also search contents of factoids TODO
		$results = $self->dbh->selectall_arrayref(
			"SELECT subject,copula,predicate 
			FROM (SELECT subject,copula,predicate FROM factoid GROUP BY original_subject) as subquery
			WHERE subject regexp ? OR predicate regexp ?", # using a subquery so that i can do this properly
			{Slice => {}},
			$search, $search,
		);
    }
    else
    {
		#XXX: need to also search contents of factoids TODO
		$results = $self->dbh->selectall_arrayref(
			"SELECT subject,copula,predicate 
			FROM (SELECT subject,copula,predicate FROM factoid GROUP BY original_subject) as subquery
			WHERE subject like ? OR predicate like ?", # using a subquery so that i can do this properly
			{Slice => {}},
			"%$body%", "%$body%",
		);
    }
    
	if( $results and @$results ) {
		my $ret_string;
		for( @$results ) {
			#i want a better string here, i'll probably go with just the subject, XXX TODO
			$ret_string .= "[" . _fact_literal_format($_) . "] " if ($_->{predicate} !~ /^\s*$/);
		}

		return $ret_string;
	}
	else {
		return "No matches."
	}
    
    
}

sub get_fact {
	my( $self, $pm, $said, $subject, $name, $call_only ) = @_;

	return $self->basic_get_fact( $pm, $said, $subject, $name, $call_only );
}	

sub _db_check_perm {
        my ($self, $subj, $said) = @_;
	my $isprot = $self->_db_get_protect($subj);

	warn "Checking permissions of [$subj] for [$said->{name}]";
	warn Dumper($said);

	#always refuse to change factoids if not in one of my channels
	return 0 if (!$said->{in_my_chan});

	#if its not protected no need to check if they are op or root;
	return 1 if (!$isprot); 

	if ($isprot && ($said->{by_root} || $said->{by_chan_op}))
	{
		return 1;
	}

	#default case, $isprotect true; op or root isn't
	return 0;
}

#get the status of the protection bit
sub _db_get_protect {
        my( $self, $subj ) = @_;

	$subj = _clean_subject($subj,1);

        my $dbh = $self->dbh;
        my $prot = ($dbh->selectrow_array( "
                        SELECT protected
                        FROM factoid
                        WHERE original_subject = ?
                        ORDER BY factoid_id DESC
                ",
                undef,
                $subj,
        ))[0];

        return $prot;
}


sub _db_get_fact {
	my( $self, $subj, $name, $func ) = @_;
	
	my $dbh = $self->dbh;
	my $fact = $dbh->selectrow_hashref( "
			SELECT factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject
			FROM factoid 
			WHERE original_subject = ?
			ORDER BY factoid_id DESC
		", 
		undef,
		$subj, 
	);
	
	if ($func && (!$fact->{compose_macro}))
	{
		return undef;
	}
	else
	{
		return $fact;
	}

}

sub basic_get_fact {
	my( $self, $pm, $said, $subject, $name, $call_only ) = @_;

	my ($fact, $key, $arg);
	$key = _clean_subject($subject);

	if( !$call_only ) {
		$fact = $self->_db_get_fact($key, $name);
	}
	# Attempt to determine if our subject matches a previously defined 
	# 'macro' or 'func' type factoid.
	# I suspect it won't match two word function names now.

	for my $variant (0, 1) {
		if (!$fact) {
			($key, $arg) = _clean_subject_func($subject, $variant);
			$fact = $self->_db_get_fact($key, $name, 1);
		}
	}

	if( $fact->{predicate} =~ /\S/ ) {
		if( $fact->{compose_macro} ) {
			my $plugin = $pm->get_plugin("compose", $said);
			
			local $said->{macro_arg} = $arg;
			local $said->{body} = $fact->{predicate};
			local $said->{addressed} = 1; # Force addressed to circumvent restrictions? May not be needed!

			return $plugin->command($said,$pm);
		}
		else {
			return "$fact->{predicate}";
		}
	}
	else {
		my $soundex = soundex( _clean_subject($subject, 1) );

		my $matches = $self->_soundex_matches( $soundex );
		
		if( ($matches and @$matches) && (!$said->{backdressed}) ) {
			return "No factoid found. Did you mean one of these: " . join " ", map "[$_]", @$matches;
		}
		else {
			return;
		}
	}
}

sub _soundex_matches {
	my( $self, $soundex ) = @_;
	my $dbh = $self->dbh;

        #XXX HACK WARNING: not really a hack, but something to document, the inner query here seems to work fine on sqlite, but i suspect on other databases it might need an ORDER BY factoid_id clause to enforce that it picks the last entry in the database
	my $rows = $dbh->selectall_arrayref(
                "SELECT * FROM (SELECT factoid_id,subject,predicate FROM factoid WHERE soundex = ? GROUP BY original_subject) as subquery WHERE NOT (predicate = ' ') LIMIT 10",
		undef,
		$soundex
	);

	return [ map $_->[1], grep $_->[2] =~ /\S/, @$rows ];
}

no warnings 'void';
"Bot::BB3::Plugin::Factoids";
__DATA__
Learn or retrieve persistent factoids. "foo is bar" to store. "foo" to retrieve. try "forget foo" or "revisions foo" or "literal foo" or "revert $REV_ID" too. "macro foo is [echo bar]" or "func foo is [echo bar [arg]]" for compose macro factoids. The factoids/fact/call keyword is optional except in compose. Search <subject> to search for factoids that match.
