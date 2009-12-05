package Bot::BB3::Roles::PasteBot;

use POE;
use POE::Component::Server::SimpleHTTP;
use HTTP::Status;
use CGI;
use Template;
use strict;

our( $INDEX_HTML, $RECEIVED_PASTE_HTML, $DISPLAY_PASTE_HTML );

sub new {
	my( $class, $conf, $pm ) = @_;

	my $self = bless { conf => $conf, pm => $pm }, $class;
	$self->{hostname} = $conf->{roles}->{pastebot}->{hostname} || "127.0.0.1";
	$self->{hostname} =~ s{^\s*http:/?/?}{};
	# TODO I think this is slightly duplicating the above data
	# Note that it can default to empty though..
	$self->{alias_url} = $conf->{roles}->{pastebot}->{alias_url};

	$self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/_start display_page index display_paste receive_paste/ ]
		]
	);

	eval { 
		$self->dbh->do( 
			"CREATE TABLE paste (
				paste_id INTEGER PRIMARY KEY AUTOINCREMENT,
				author VARCHAR(200),
				summary VARCHAR(250),
				paste LONGTEXT,
				date_time INTEGER
			)"
		);
	};

	return $self;
}

# This method may be called as either a class method or an object method
# so we have to have some ugly branches to account for it.
sub dbh {
	my( $self ) = @_;

	if( ref $self and  $self->{dbh} and $self->{dbh}->ping ) {
		return $self->{dbh};
	}

	my $dbh = DBI->connect( "dbi:SQLite:dbname=var/pastes.db", "", "", {RaiseError => 1, PrintError => 0} )
		or die "Failed to create DBI connection to var/pastes.db, this is a Big Problem! $!";

	if( ref $self ) {
		$self->{dbh} = $dbh;
	}
	
	return $dbh;
}	

# This is a public method that can be called as a class method
# therefor $self may be a class or an object.
sub get_paste {
	my( $self, $paste_id ) = @_;

	my $paste = $self->dbh->selectrow_hashref( 
		"SELECT author,summary,paste,date_time FROM paste WHERE paste_id = ? LIMIT 1",
		undef,
		$paste_id
	);

	return $paste;
}

sub insert_paste {
	my( $self, $nick, $summary, $paste )= @_;

	my $dbh = $self->dbh;
	$dbh->do(
		"INSERT INTO paste
			(author, summary, paste, date_time)
			VALUES (?,?,?,?)
		",
		undef,
		$nick,
		$summary,
		$paste,
		time
	);

	my $id = $dbh->last_insert_id( undef, undef, undef, undef );

	return $id;
}


sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];
	my $conf = $self->{conf};

	# Create it here so it acts as a child
	$self->{server} = POE::Component::Server::SimpleHTTP->new(
		PORT => $conf->{pastebot_plugin_port},
		ADDRESS => $conf->{pastebot_plugin_addr} || undef,
		ALIAS => 'pb_httpd_alias',
		HANDLERS => [
			{
				DIR => '^/paste/\d+',
				SESSION => "pastebot_role",
				EVENT => "display_paste",
			},
			{
				DIR => '^/paste_submit',
				SESSION => "pastebot_role",
				EVENT => "receive_paste",
			},
			{
				DIR => '^/',
				SESSION => "pastebot_role",
				EVENT => "index",
			},

		]
	);

	$kernel->alias_set( "pastebot_role" );
	$kernel->sig("DIE" => 'sig_DIE' );
}

sub display_page {
	my( $self, $resp, $html ) = @_[OBJECT,ARG0,ARG1,ARG2];
	
	warn "Display Page Activating: $resp\n";

	$resp->code(RC_OK);
	$resp->content_type("text/html");
	$resp->content( $html );
	
	$_[KERNEL]->post(  pb_httpd_alias => 'DONE' => $resp );
}

sub index {
	my( $self, $kernel, $req, $resp ) = @_[OBJECT,KERNEL,ARG0,ARG1];

	my $template = Template->new;
	my $channels = $kernel->call("Bot::BB3::Roles::IRC", "channel_list")
		or warn "Failed to call: $!";
	my $context = {
		channels => $channels, 
		alias_url => $self->{alias_url},
	};

	my $output_html;
	$template->process( \$INDEX_HTML, $context, \$output_html )
		or warn "Failed to process: $Template::ERROR\n";

	$_[KERNEL]->yield( display_page => $resp, $output_html );
}

sub display_paste {
	my( $self, $req, $resp ) = @_[OBJECT,ARG0,ARG1];
	
	my $output_html = "<body>Invalid Paste ID</body>";

	$req->uri =~ m{paste/(\d+)}
		or goto CLEANUP;
	
	my $paste_id = $1;


	my $paste = $self->get_paste( $paste_id );

	if( not $paste or not keys  %$paste ) { goto CLEANUP; }

	my $template = Template->new;
	my $context = {
		author => $paste->{author},
		summary => $paste->{summary},
		paste => $paste->{paste},
		date_time => $paste->{date_time},
	};

	undef $output_html;
	$template->process( \$DISPLAY_PASTE_HTML, $context, \$output_html );


	CLEANUP:
	$_[KERNEL]->yield( display_page => $resp, $output_html );
}

sub receive_paste {
	my( $self, $req, $resp ) = @_[OBJECT,ARG0,ARG1];

	warn "Request: ", $req->content;

	my $query = CGI->new( $req->content );
	my $input = $query->param("body");

	warn "Attempting to handle request: $req $resp $input\n";

	my $id = $self->insert_paste(
		$query->param("nick"),
		$query->param("summary"),
		$query->param("paste"),
		time
	);

	my $template = Template->new;
	my $context = {
		map { $_ => $query->param( $_ ) } qw/nick summary channel paste/,
		id => $id,
		alias_url => $self->{alias_url},
	};

	my $output;
	$template->process( \$RECEIVED_PASTE_HTML, $context, \$output )
		or warn $Template::ERROR;

	$_[KERNEL]->yield( display_page => $resp, $output ); 

	my $alert_channel = $query->param("channel");

	if( $alert_channel !~ /^\s*---/ ) { # Ignore things like "---irc.freenode, skip server names
		my($server,$nick,$channel) = split /:/,$alert_channel,3;

		my $external_url = $self->{alias_url} || $self->{hostname};
		$_[KERNEL]->post( "Bot::BB3::Roles::IRC", external_message => $server, $nick, $channel,
			( $context->{nick} || "Someone" )
				. " pasted a new file at $external_url/paste/$id - $context->{summary}"
		);
	}
}


sub sig_DIE {
	# Do nothing, we're ignoring fatal errors from our child, poco-server-simplehttp. I think we don't need to respawn them.
}


$INDEX_HTML = <<'END_HTML';
<html>
	<head>
		<style>
			#summary {
				width: 60em;
			}
			#paste {
				width: 80em;
				height: 25em;
			}
		</style>
	</head>

	<body>
	<h2>Welcome to the BB3 Pastebot.</h2>
	<ol>
		<li>Select the channel for the URL announcment.</li>
		<li>Supply a nick for the announcement.</li>
		<li>Supply a summary of the paste for the announcement.</li>
		<li>Paste!</li>
		<li>Submit the form with the Paste it! button.</li>
	</ol>

	<form action="[% alias_url %]/paste_submit" method="post">
	<ol>
		<li style="float: left">Channel: 
			<select name="channel" id="channel">
				[% FOREACH server IN channels.keys %]
					<option name="channel">----[% server %] </option>

						[% FOREACH nick IN channels.$server.keys %]
							[% FOREACH channel IN channels.$server.$nick %]
							<option value="[% server %]:[% nick %]:[% channel %]">[% channel %]</option>
							[% END %]
						[% END %]
				[% END %]
			</select>
		</li>
		<li style="float: left; clear: right; margin-left: 10em;">Nick: 
			<input type="text" name="nick" id="nick">
		</li>
		<li style="clear: both;">Summary:
			<input type="text" name="summary" id="summary">
		</li>
		<li>Paste:
			<textarea name="paste" id="paste"></textarea>
		</li>
		<li>
			<input type="submit" name="paster" value="Paste It!">
			<input type="reset" value="Clear Form">
		</li>
	</ol>
	</form>


	</body>
</html>
END_HTML

$RECEIVED_PASTE_HTML = <<'END_HTML';
<html>
	<head>
		<style>
		</style>
	</head>

	<body>
		Stored as: <a href="[% alias_url %]/paste/[% id %]">Paste [% id %]</a>
		<br> [% summary %] by [% nick %] <br>
		<pre>[% paste | html %]</pre>
	</body>
</html>
END_HTML

$DISPLAY_PASTE_HTML = <<'END_HTML';
<html>
	<head>
		<style>
			#paste {
				width: 95%;
				background-color: rgb(230,230,230);
			}
		</style>
	</head>

	<body>
		<h2> BB3 PasteBot</h2>
		<h3>From [% author | html %]</h3>
		<h4>[% summary | html %]</h4>
		<pre id="paste">[% paste | html %]</pre>
	</body>
</html>

END_HTML

1;
