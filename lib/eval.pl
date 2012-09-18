#!perl

#use lib '/home/ryan/perl5/lib/perl5/i686-linux';
#use lib '/home/ryan/perl5/lib/perl5';

use strict;
use Data::Dumper;
use Scalar::Util; #Required by Data::Dumper
use BSD::Resource;
use File::Glob;
use POSIX;

use List::Util;
use List::MoreUtils;
use List::UtilsBy;
use Data::Munge;
use Scalar::MoreUtils;
use Regexp::Common;
use Encode;
use Digest::MD5;
use Digest::SHA;
use DateTime;
use DateTimeX::Easy;
use Date::Parse;
use Time::Piece;

require Moose;
require MooseX::Declare;
eval "use MooseX::Declare; class Foo { has dongs => ( is => ro, isa => 'Int' ); };";
require "utf8_heavy.pl";


# save the old stdout, we're going to clobber it soon. STDOUT
my $oldout;
my $outbuffer = "";
open($oldout, ">&STDOUT") or die "Can't dup STDOUT: $!";
open(my $stdh, ">", \$outbuffer) 
               or die "Can't dup to buffer: $!";
select($stdh);
$|++;
#*STDOUT = $stdh;

no warnings;

# This sub is defined here so that it is defined before the 'use charnames'
# command. This causes extremely strange interactions that result in the
# deparse output being much longer than it should be.
	sub deparse_perl_code {
		my( $code ) = @_;
		my $sub = eval "no strict; no warnings; no charnames; sub{ $code\n }";
		if( $@ ) { print STDOUT "Error: $@"; return }

		my $dp = B::Deparse->new("-p", "-q", "-x7");
		my $ret = $dp->coderef2text($sub);

			$ret =~ s/\{//;
			$ret =~ s/package (?:\w+(?:::)?)+;//;
			$ret =~ s/ no warnings;//;
			$ret =~ s/\s+/ /g;
			$ret =~ s/\s*\}\s*$//;

		print STDOUT $ret;
	}

use utf8; eval "\$\343\201\257 = 42; 'ש' =~ /([\p{Bidi_Class:L}\p{Bidi_Class:R}])/";  # attempt to automatically load the utf8 libraries.
use charnames qw(:full);
use PerlIO;
use PerlIO::scalar;
use Text::ParseWords;

# Required for perl_deparse
use B::Deparse;

# Javascript Libs
BEGIN{ eval "use JavaScript::V8; use JSON::XS; JavaScript::V8::Context->new()->eval('1')"; }
my $JSENV_CODE = do { local $/; open my $fh, "deps/env.js"; <$fh> };
require 'bytes_heavy.pl';

use Tie::Hash::NamedCapture;

 {#no warnings 'constant';
 uc "\x{666}"; #Attempt to load unicode libraries.
 lc "JONQUIÉRE";
 }
 binmode STDOUT, ":utf8"; # Enable utf8 output.

BEGIN{ eval "use PHP::Interpreter;"; }

# Evil Ruby stuff
BEGIN{ eval "use Ruby qw/rb_eval/;"; }
BEGIN { $SIG{SEGV} = sub { die "Segmentation Fault\n"; } } #Attempt to override the handler Ruby installs.

# Evil K20 stuff
BEGIN {
	local $@;
	eval "use Language::K20;"; 
	unless( $@ ) {
		Language::K20::k20eval( "2+2\n" ); # This eval loads the dynamic components before the chroot.
                                   # Note that k20eval always tries to output to stdout so we
                                   # must end the command with a \n to prevent this output.
	}
}

BEGIN { chdir "var/"; $0="../$0"; } # CHDIR to stop inline from creating stupid _Inline directories everywhere
# Inline::Lua doesn't seem to provide an eval function. SIGH.
BEGIN { eval 'use Inline Lua => "function lua_eval(str) return loadstring(str) end";'; }
BEGIN { chdir ".."; $0=~s/^\.\.\/// } # Assume our earlier chdir succeded. Yay!


# Evil python stuff
BEGIN { eval "use Inline::Python qw/py_eval/;"; }

# Evil J stuff
BEGIN { eval "use Jplugin;"; }

use Carp::Heavy;
use Storable qw/nfreeze/; nfreeze([]); #Preload Nfreeze since it's loaded on demand

	my $code = do { local $/; <STDIN> };


	# Close every other filehandle we may have open
	# this is probably legacy code at this point since it was used
	# inside the original bb2 which forked to execute this code.
	opendir my $dh, "/proc/self/fd" or die $!;
	while(my $fd = readdir($dh)) { next unless $fd > 2; POSIX::close($fd) }

	# Get the nobody uid before we chroot.
	my $nobody_uid = getpwnam("nobody");
	die "Error, can't find a uid for 'nobody'. Replace with someone who exists" unless $nobody_uid;

	# Set the CPU LIMIT.
	# Do this before the chroot because some of the other
	# setrlimit calls will prevent chroot from working
	# however at the same time we need to preload an autload file
	# that chroot will prevent, so do it here.
	setrlimit(RLIMIT_CPU, 10,10);

	# Root Check
	if( $< != 0 )
	{
		die "Not root, can't chroot or take other precautions, dying\n";
	}

	# The chroot section
	chdir("./jail") or
		do {
			mkdir "./jail";
			chdir "./jail" or die "Failed to find a jail live in, couldn't make one either: $!\n";
		};

	chroot(".") or die $!;

	# Here's where we actually drop our root privilege
	$)="$nobody_uid $nobody_uid";
	$(=$nobody_uid;
	$<=$>=$nobody_uid;
	POSIX::setgid($nobody_uid); #We just assume the uid is the same as the gid. Hot.
	
	die "Failed to drop to nobody"
		if $> != $nobody_uid
		or $< != $nobody_uid;
	
	my $kilo = 1024;
	my $meg = $kilo * $kilo;
	my $limit = 150 * $meg;

        # clobber stdout before we set rlimits.  otherwise we can't do anything STDOUT

	(
	setrlimit(RLIMIT_VMEM, 1024*$meg, 1024*$meg)
		and
	setrlimit(RLIMIT_DATA, $limit, $limit )
		and
	setrlimit(RLIMIT_STACK, $limit, $limit )
		and
	setrlimit(RLIMIT_NPROC, 1,1)
		and
	setrlimit(RLIMIT_NOFILE, 0,0)
		and
	setrlimit(RLIMIT_OFILE, 0,0)
		and
	setrlimit(RLIMIT_OPEN_MAX,0,0)
		and
	setrlimit(RLIMIT_LOCKS, 0,0)
		and
	setrlimit(RLIMIT_AS,$limit,$limit)
		and
	setrlimit(RLIMIT_MEMLOCK,100,100)
		and
	setrlimit(RLIMIT_CPU, 10,10)
	)
		or die "Failed to set rlimit: $!";

        %ENV=();
	#setrlimit(RLIMIT_MSGQUEUE,100,100);

	die "Failed to drop root: $<" if $< == 0;
	close STDIN;

	$code =~ s/^\s*(\w+)\s*//
		or die "Failed to parse code type! $code";
	my $type = $1;

	# Chomp code..
	$code =~ s/\s*$//;

	# Choose which type of evaluation to perform
	# will probably be a dispatch table soon.
	if( $type eq 'perl' or $type eq 'pl' ) {
		perl_code($code);
	}
	elsif( $type eq 'javascript' ) {
		javascript_code($code);
	}
	elsif( $type eq 'php' ) {
		php_code($code);
	}
	elsif( $type eq 'deparse' ) {
		deparse_perl_code($code);
	}
	elsif( $type eq 'k20' ) {
		k20_code($code);
	}
	elsif( $type eq 'rb' or $type eq 'ruby' ) {
		ruby_code($code);
	}
	elsif( $type eq 'py' or $type eq 'python' ) {
		python_code($code);
	}
	elsif( $type eq 'lua' ) {
		lua_code($code);
	}
	elsif( $type eq 'j' ) {
		j_code($code);
	}

#        *STDOUT = $oldout;
        close($stdh);
        select(STDOUT);
        print($outbuffer);

	exit;

	#-----------------------------------------------------------------------------
	# Evaluate the actual code
	#-----------------------------------------------------------------------------
	sub perl_code {
		my( $code ) = @_;
		local $@;
		local @INC;
 
		local $_;

		$code = "no strict; no warnings; package main; $code";
		my $ret = eval $code;

		local $Data::Dumper::Terse = 1;
		local $Data::Dumper::Quotekeys = 0;
		local $Data::Dumper::Indent = 0;
		local $Data::Dumper::Useqq = 1;

		my $out = ref($ret) ? Dumper( $ret ) : "" . $ret;

		print $out unless $outbuffer;

		if( $@ ) { print "ERROR: $@" }
	}



	sub javascript_code {
		my( $code ) = @_;
		local $@;

		my $js = JavaScript::V8::Context->new;

		# Set up the Environment for ENVJS
		$js->bind("print", sub { print @_ } );
		$js->bind("write", sub { print @_ } );

#		for( qw/log debug info warn error/ ) {
#			$js->eval("Envjs.$_=function(x){}");
#		}

#		$js->eval($JSENV_CODE) or die $@;

                $code =~ s/(["\\])/\\$1/g;
                my $rcode = qq{write(eval("$code"))};

       

		my $out = eval { $js->eval($rcode) };

		if( $@ ) { print "ERROR: $@"; }
                else { print encode_json $out }
	}

	sub ruby_code {
		my( $code ) = @_;
		local $@;

		print rb_eval( $code );
	}

	sub php_code {
		my( $code ) = @_;
		local $@;

		#warn "PHP - [$code]";

		my $php = PHP::Interpreter->new;

		$php->set_output_handler(\ my $output );

		$php->eval("$code;");

		print $php->get_output;

		#warn "ENDING";

		if( $@ ) { print "ERROR: $@"; }
	}

	sub k20_code {
		my( $code ) = @_;

		$code =~ s/\r?\n//g;

		
		Language::K20::k20eval( '."\\\\r ' . int(rand(2**31)) . '";' . "\n"); # set random seed
		
		Language::K20::k20eval(	$code );
	}

	sub python_code {
		my( $code ) = @_;

		py_eval( $code, 2 );
	}

	sub lua_code {
		my( $code ) = @_;

		#print lua_eval( $code )->();

		my $ret = lua_eval( $code );

		print ref $ret ? $ret->() : $ret;
	}

	sub j_code {
		my( $code ) = @_;

		Jplugin::jplugin( $code );
	}
