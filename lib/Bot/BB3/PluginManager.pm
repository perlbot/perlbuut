package Bot::BB3::PluginManager;

use Bot::BB3::PluginWrapper;
use Bot::BB3::Logger;
use POE;
use Data::Dumper;
use Text::Glob qw/match_glob/;
use Memoize;
use strict;

sub new {
	my( $class, $main_conf, $plugin_conf, $bb3 ) = @_;

	my $self = bless { 
		main_conf => $main_conf,
		plugin_conf => $plugin_conf,
		bb3 => $bb3, # A bit hacky, only used for special commands from plugin at the moment
	}, $class;

	$self->{child_cache} = $self->create_cache;

	$self->_load_plugins();

	$self->{session} = POE::Session->create(
		object_states => [
			$self => [ qw/
					_start execute_said handle_said_queue adjust_child_count
					please_die child_flushed child_output child_err child_fail 
					child_close child_die child_time_limit 
				/ ]
		]
	);

	return $self;
}

#---------------------
# Helpers and accessors
#---------------------

sub yield {
	my ( $self, $event, @args ) = @_;

	warn "YIELD CALLED: $event\n";

	return POE::Kernel->post( $self->{session}, $event, @args );
}

sub call {
	my ( $self, $event, @args ) = @_;

	warn "CALL CALLED: $event\n";

	return POE::Kernel->call( $self->{session}, $event, @args );
}

sub get_main_conf {
	return $_[0]->{main_conf};
}

sub get_plugin_conf {
	return $_[0]->{plugin_conf};
}

sub get_plugins {
	my( $self ) = @_;
	return $self->{plugins};
}

sub get_plugin {
	my( $self, $name, $said ) = @_;

	# Loops are cool.
	# O(n) but nobody cares because it's rarely used.
	# HA HA THIS IS A LIE.

	#this fixes a security flaw, but not completely because i'm lazy right now
        my $filtered =  $self->{plugins}; 
	$filtered = $self->_filter_plugin_list($said, $filtered) if ($said);

	for( @{$filtered} ) {
		if( $name eq $_->{name} ) { 
			return $_;
		}

		if( $_->{aliases} ) {
			for my $alias ( @{ $_->{aliases} } ) {
				return $_ if $name eq $alias;
			}
		}
	}

	return;
}
memoize( 'get_plugin' ); #Fixes that pesk O(n) thingy.

sub kill_children {
	my( $self ) = @_;

	for( values %{ $self->{children} } ) {
	warn "KILLING: ", $_->{wheel}->PID, ": ",
		kill( 9, $_->{wheel}->PID ); #DIE DIE DIE
	}
}

sub reload_plugins {
	my( $self ) = @_;

	delete $self->{plugins};
	$self->_load_plugins();
	# In theory we just kill our children and they're 
	# automatically respawned by the various child
	# death handlers.
	$self->kill_children();
}

sub create_cache {
	my( $self ) = @_;

	eval { require Cache::FastMmap; }
		and return Cache::FastMmap->new( share_file => "var/cache-fastmmap", init_file => 1 );

	eval { require Cache::Mmap; }
		and return Cache::Mmap->new( "var/cache-mmap", { buckets => 89, bucketsize => 64 * 1024 } );

	eval { require Cache::File; }
		and return Cache::File->new( cache_root => 'var/cache-file', default_expires => '6000 sec' );
	
	die "Failed to properly create a cache object! Please install Cache::FastMmap, Cache::Mmap or Cache::File\n";
}

#---------------------
# Loading methods
#---------------------

sub _load_plugins {
	my( $self ) = @_;

	my $plugin_dir = $self->{main_conf}->{plugin_dir} || 'plugins';
	
	opendir my $dh, $plugin_dir or die "Failed to open plugin dir: $plugin_dir: $!\n";

	while( defined( my $file = readdir $dh ) ) {
		next unless $file =~ /\.pm$/;

		local $@;
		local *DATA; # Prevent previous file's __DATA__ 
		             # sections being read for this new file.
		my $plugin_return = do "$plugin_dir/$file";
		if( not $plugin_return or $@ ) {
			error "Failed to load plugin: $plugin_dir/$file $@\n";
			next;
		}

		(my $name = $file) =~ s/\.pm$//;
		my $plugin_obj;
		my $help_text;

		if( ref $plugin_return eq 'CODE' ) {
			$plugin_obj = Bot::BB3::PluginWrapper->new( $name, $plugin_return );
			$help_text = join '', <DATA>;
		}
		elsif( ref $plugin_return eq '' ) { #String representing package name, I hope
			local $@;
			eval {
				$plugin_obj = $plugin_return->new();

				# Fo' Realz. 
				# strict won't let me abuse typeglob symbolic refs properly!
				no strict;
				if( *{"${plugin_return}::DATA"}{IO} ) {
					$help_text = join '', readline *{"${plugin_return}::DATA"};
				}
			};

			if( not $plugin_obj or $@ ) {
				warn "Failed to instantiate $plugin_return from $plugin_dir/$file $@\n";
				next;
			}
		}

		if( not $plugin_obj ) {
			warn "Failed to get a plugin_obj from $plugin_dir/$file for unknown reasons $plugin_return.\n";
			next;
		}

		$plugin_obj->{help_text} = $help_text;

		push @{ $self->{plugins} }, $plugin_obj;
	}

	$self->_pre_build_plugin_chain();
	$self->_pre_load_default_plugin();
	
	for my $plugin ( @{ $self->{plugins} } ) {
		local $@;
		$plugin->can("postload") and
			eval { $plugin->postload($self) };
		if( $@ ) { warn "$plugin->{name}: postload failed: $@"; }
	}

	return scalar @{ $self->{plugins} };
}

sub _pre_build_plugin_chain {
	my( $self ) = @_;
	my $plugins = $self->{plugins};

	my( $pre,$post,$commands,$handlers );
	for my $plugin ( @$plugins ) {
		my $opts = $plugin->{opts};

		if( $opts->{pre_process} ) {
			push @$pre, $plugin;
		}

		if( $opts->{post_process} ) {
			push @$post, $plugin;
		}

		if( $opts->{command} ) {
			$commands->{ $plugin->{name} } = $plugin;
			
			if( $plugin->{aliases} ) {
				$commands->{ $_ } = $plugin
					for @{ $plugin->{aliases} };
			}
		}

		if( $opts->{handler} ) {
			push @$handlers, $plugin;
		}
	}

	$self->{plugin_chain} = {
		pre_process => $pre,
		post_process => $post,
		commands => $commands,
		handlers => $handlers
	};
}

sub _pre_load_default_plugin {
	my( $self ) = @_;

	if( my $default = $self->{main_conf}->{plugin_manager}->{default_plugin} ) {
		if( not ref $default ) { $default = [$default] } # Clean up Config::General randomness

		my @default_chain;
		for( @$default ) {
			my @plugins = split " ", $_; #I'm not really sure what the format is. Also, magic split.

			for( @plugins ) { 
				my $plugin = $self->get_plugin( $_ );
				if( $plugin ) { push @default_chain, $plugin }
			}
		}

		$self->{default_plugin_chain} = \@default_chain;
	}
	else {
		$self->{default_plugin_chain} = [];
	}
}

#--------------------------------
# Executed inside the forked child
#--------------------------------
sub _start_plugin_child {
	my( $self ) = @_;

	srand; # We deliberately call srand since when we fork all children will have the same initial seed

	#POE::Kernel->run; # Attempt to suppress the warning about ->run never being called.

	for( @{ $self->get_plugins } ) {
		if( $_->can('initialize') ) {
			local $@;
			eval { $_->initialize($self, $self->{child_cache}) };
			if( $@ ) { warn "$_->{name} failed to initialize: $@"; }
		}
	}

	my $filter = POE::Filter::Reference->new;
	binmode( STDIN ); binmode( STDOUT );

	my $handled_counter = 0;

	while( 1 ) {
		my $stream;
		sysread STDIN, $stream, 4096 
			or die "Child $$ failed to read: $!\n";

		my $filter_refs = $filter->get( [$stream] );

		for my $said ( @$filter_refs ) {
			$handled_counter++;

			#-----
			# Execute chain
			#-----
			my $chain = $self->_create_plugin_chain( $said );

			# Only add the default if we're being addressed
			if( $said->{addressed} ) {
				push @{ $chain->[1] }, @{ $self->{default_plugin_chain} }; # Append default plugins to the command section
																																	 # of the plugin chain
			}
			
			my $results = $self->_execute_plugin_chain( $said, $chain );

			warn "Got some output: [$results]\n";

			if( $results !~ /\S/ and $said->{addressed} ) {
				#$results = "Couldn't match input.";
			}

			#----
			# Output
			#----
			#if( length $results and $results =~ /\S/) {
				# Always output something so the handler knows we're done.
				for( @{$filter->put([ [$said, $results] ])} ) {
					syswrite STDOUT, $_;
				}
			#}
		}

		if( $handled_counter > $self->{main_conf}->{child_handle_count} ) {
			last;
		}
	}

	warn "$$: Fell off the end, exiting\n";

	# Exit the child
	exit;
}

sub _create_plugin_chain {
	my( $self, $said ) = @_;
	my $pre_built_chains = $self->{plugin_chain};

	my( $pre, $post ) = @{$pre_built_chains}{ qw/pre_process post_process/ };
	my $handlers = $self->_filter_plugin_list( $said, $pre_built_chains->{ handlers } );
	;		
	#---
	# Parse said/commands
	#---
	my $commands = $pre_built_chains->{commands};
	my $command_list = $self->_parse_for_commands( $said, $commands );

	return [ $pre, $command_list, $handlers, $post ];
	
}

sub _parse_for_commands {
	my( $self, $said, $commands ) = @_;

	my $command_re = join '|', map "\Q$_", keys %$commands;
	$command_re = qr/$command_re/; #TODO move to _pre_build_chains and switch to Trie

	if( (!$said->{addressed} && $said->{body} =~ s/^\s*($command_re)[:,;]\s*(.+)/$2/)
          or ($said->{addressed} && $said->{body} =~ s/^\s*($command_re)[ :,;-]\s*(.+)/$2/)
		or $said->{body} =~ s/^\s*($command_re)\s*$// ) {

			my $found_command = $1;
			my $args = $2;
			my $command = $commands->{ $found_command };

			warn "found $found_command - $args\n";

			# takes and returns array ref
			my $filter_check = $self->_filter_plugin_list( $said, [$command] );
			if( @$filter_check ) { # So check if the one argument passed
				# Return an array ref..
				$said->{recommended_args} = [ split /\s+/, $args ];
				$said->{command_match} = $found_command;
				return $filter_check;
			} 
	}

	return [];
}

sub _filter_plugin_list {
	my( $self, $said, $plugins ) = @_;

	my @chain;
	for( @$plugins ) {
		my $conf = $self->plugin_conf( $_->{name}, $said->{server}, $said->{channel} );

		# Explicitly skip addressed checks for special channels
		if( $said->{channel} !~ /^\*/ ) {
			next if $conf->{addressed} and not $said->{addressed};
		}

		next if $conf->{access} eq 'op' and not ( $said->{by_chan_op} or $said->{by_root} );
		next if $conf->{access} eq 'root' and not $said->{by_root};

		push @chain, $_;
	}

	return \@chain;
}

sub _execute_plugin_chain {
	my( $self, $said, $chain ) = @_;
	my( $pre, $commands, $handlers, $post ) = @$chain;

	for( @$pre ) { 
		$_->pre_process( $said, $self );
	}

	my $total_output = [];
	for( @$commands ) {
		local $@;
		my( $return, $output ) = eval { $_->command( $said, $self ) };

		if( $@ ) { push @$total_output, "Error: $@"; next; }

		warn "$_->{name} - $return - $output\n";

		push @$total_output, $output;
		
		if( $return eq 'handled' ) {
			last;
		}
	}

	for( @$handlers ) {
		local $@;
		my( $output ) = eval { $_->handle( $said, $self ) };

		if( $@ ) { push @$total_output, "Error: $@"; next; }

		push @$total_output, $output;
	}

	my $output = join " ", @$total_output;

	for( @$post ) {
		$_->post_process( $said, $self, \$output );
	}

	return $output;
}

#--------------------------------

# Note, really queues the event.
# Should definitely only be called by
# external users at this point..
sub execute_said {
	my( $self, $kernel, $sender, $said ) = @_[OBJECT,KERNEL,SENDER,ARG0];
	$said->{parent_session} = $sender->ID unless $said->{parent_session};

	warn "Queuing said.. $said->{body}\n";

	push @{ $self->{said_queue} }, $said;

	$self->yield( 'handle_said_queue' );
}

sub handle_said_queue {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];
	my $queue = $self->{said_queue};
	my $children = [ values %{ $self->{children} } ];

	return unless $queue and @$queue;

	while( defined( my $said = shift @$queue ) ) {
		warn "Queuing $said\n";

		for( @$children ) { 
			warn "Checking ", $_->{wheel}->PID, ": $_->{queue}";
			if( not $_->{queue} ) {
				$_->{queue} = $said;
				$_->{wheel}->put( $said );
				$said->{attempts}++;
				warn "Queueing $said for ", $_->{wheel}->PID;
				last;
			
			}
		}
	}

	if( $queue and @$queue ) { 
		$kernel->delay( handle_said_queue => 2 );
	}
}

# Helper method!
sub _spawn_child {
	my( $self ) = @_;

		my $child = POE::Wheel::Run->new(
			Program => sub { $self->_start_plugin_child; },

			NoSetSid => 1, #Ensure that SIGINTS to the main process kill our children
			StdioFilter => POE::Filter::Reference->new,
			StderrFilter => POE::Filter::Line->new,
			
			StdinEvent  => 'child_flushed',
			StdoutEvent => 'child_output',
			StderrEvent => 'child_err',
			ErrorEvent  => 'child_fail',
			CloseEvent  => 'child_close',
		);

		#push @{ $self->{children} }, $child;

		my $child_struct = {
			wheel => $child,
			graceful_shutdown => 0,
			queue => 0,
		};
		$self->{children}->{ $child->ID } = $child_struct;
		$self->{children_by_pid}->{ $child->PID } = $child->ID; 

		warn "Created child: ", $child->ID;

		$poe_kernel->sig_child( $child->PID, 'child_die' );
}

# This is probably called multiple times every time a child dies
# so we need to make sure it gracefully handles all of the possible
# cases.
sub child_die {
	my( $self, $pid ) = @_[OBJECT,ARG1];

	my $id = delete $self->{children_by_pid}->{$pid};

	return unless $id;

	# Delete child operation
	warn "Deleting: $id";
	my $child = delete $self->{children}->{$id};

	return unless $child;

	# If the dead child had a queue ready then we requeue to make sure it
	# gets handled eventually.
	# If the $said has been tried a couple of times it's probably causing 
	# the child to die some how, so we skip it.
	if( $child->{queue} and $child->{queue}->{attempts} < 2 ) { 
		#TODO methodize! (unshift and handle)
		unshift @{ $self->{said_queue} }, $child->{queue};
		$self->yield( 'handle_said_queue' );
	}

	# Go go gadget reproduction.
	$self->_spawn_child;
}

#---------------------------------------------
# Getters
#---------------------------------------------
sub get_children {
	return values %{ $_[0]->{children} };
}

#---------------------------------------------
sub _start {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];
	my $start_child_count = $self->{main_conf}->{start_plugin_children};

	for( 1 .. $start_child_count ) {
		$self->_spawn_child();
	}

	$kernel->delay_set( 'adjust_child_count', 5 );
}

sub adjust_child_count {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];

	#for( @w
}

sub child_flushed {
	my( $self, $kernel, $child_id ) = @_[OBJECT,KERNEL,ARG0];

	my $child = $self->{children}->{$child_id};
	$child->{flush_time} = time;

	$kernel->delay_set( child_time_limit => 25, $child_id, $child->{queue} );

	warn "Flushed to child $child_id\n";
}

sub child_output {
	my( $self, $kernel, $output, $child_id ) = @_[OBJECT,KERNEL,ARG0,ARG1];
	my( $said, $text ) = @$output;

	warn "Got some child output! $text\n";

	my $child = $self->{children}->{$child_id};
	warn "Deleting child queue: $child_id, $child->{queue}";
	$child->{queue} = undef;

	$self->yield('handle_said_queue');

	#TODO turn into a method (respond to parent)
	my $parent = $said->{parent_session};

	if( my $commands = delete $said->{special_commands} ) {
		for( @$commands ) {
			my $name = shift @$_;

			if( $name =~ s/^pci_// ) {
				$kernel->post( $parent => handle_special_commands => $said, $name, @$_ );
			}
			elsif( $name =~ s/^pm_// ) {
				$self->$name( @$_ );
			}
			elsif( $name =~ s/^bb3_// ) {
				$self->{bb3}->$name( @$_ );
			}
		}
	}
	
	#if( length $text and $text =~ /\S/) {
		# Always post back to our user.
		$kernel->post( $parent => 'plugin_output', $said, $text );
	#}
}

sub child_err {
	my( $self, $err_output, $child_id ) = @_[OBJECT,ARG0,ARG1];

	return unless $err_output =~ /\S/;

	warn "\n\tChild $child_id: $err_output\n";
}

sub child_fail {
	my( $self, $op, $err_num, $err_str, $child_id ) = @_[OBJECT,ARG0,ARG1,ARG2,ARG3];
	my $child = $self->{children}->{$child_id};

	return unless $child;

	warn "Crap, our child $child_id failed: $op $err_num $err_str\n";

	$self->yield( child_die => $child->{wheel}->PID );
}

sub child_close {
	my( $self, $child_id ) = @_[OBJECT,ARG0];
	my $child = $self->{children}->{$child_id};

	return unless $child;
	
	warn "Child $child_id closed\n";

	$self->yield( child_die => $child->{wheel}->PID );
}

sub child_time_limit {
	my( $self, $kernel, $child_id, $queue_ref ) = @_[OBJECT,KERNEL,ARG0,ARG1];
	my $child = $self->{children}->{$child_id};

	warn "Checking the time limit on $child_id";
	
	if( $child and $child->{queue} == $queue_ref ) {
		if( time() - $child->{flush_time} > 20 ) {
			warn "Killing $child_id because $child->{flush_time} is more than 20 ago from ", time();
			kill 9, $child->{wheel}->PID;
		}
		else {
			$kernel->delay_set( child_time_limit => 10, $child_id, $queue_ref );
		}
	}
	# If they don't match, child has already responded and we can ignore it.
}


sub please_die {
	my( $self, $kernel ) = @_[OBJECT,KERNEL];

	$self->kill_children();
}

#-------------------
# Slightly less random cruft.
# Used by plugins. Move to common
# plugin base class?
#-------------------

sub create_table {
	my( $self, $dbh, $table_name, $create_table_sql ) = @_;

	local $@;
	eval {
		$dbh->do("SELECT * FROM $table_name LIMIT 1");
	};

	if( $@ =~ /no such table/ ) {
		# Race Conditions could cause two threads to create this table.
		local $@;
		eval {
			$dbh->do( $create_table_sql );
		}; 

		# Stupid threading issues.
		# All of the children try to do this at the same time.
		# Suppress most warnings.
		if( $@ and $@ !~ /already exists/ and $@ !~ /database schema has changed/ ) {
			error "Failed to create table: $@\n";
		}

		#Success!
	}
	elsif( $@ ) {
		error "Failed to access dbh to test table: $@";
		warn "Caller: ", join " ", map "[$_]", caller;
	}
}


#-------------------------------------------
# Random cruft
# Should probably be moved somewhere.
#-------------------------------------------
{
	my %plugin_conf_cache;

	sub plugin_conf
	{
		my( $self, $command, $server, $channel ) = @_;
		my $plugin_conf = $self->{plugin_conf};

		if( local $_ = $plugin_conf_cache{$server}->{$channel}->{$command} ) {
			return $_;
		}

		my $opts = {};
		for( @$plugin_conf )
		{
			my $glob = $_->[1];
			if( match_glob( lc $glob, lc $server ) )
			{    
				for( @{ $_->[2] } )
				{    
					if( match_glob( lc $_->[1], lc $channel ) )
					{
						for( @{ $_->[2] } )
						{
							if( match_glob( lc $_->[1], lc $command ) )  
							{
								my $new_opts = $_->[2];
								$opts = { %$opts, %$new_opts };
							}
						}
					}
				}    
			}    
		}

		# Convert 'false' type strings into perl false values.
		for( keys %$opts )
		{
			my $v = $opts->{$_};

			if( $v eq 'false' or $v eq 'null' or $v eq 'off' or $v eq 0 )
			{    
				$opts->{$_} = undef;
			}    
		}

		$plugin_conf_cache{$server}->{$channel}->{$command} = $opts;

		return $opts;
	}
}

1;
